classdef EmergencyBrakeProcessor
    properties (Access = private)
        % Configuration from constructor
        maxDeceleration double
        numRangeBins
        numDopplerBins
        rangeIdxToMeters double
        dopplerResolutionMps double

        % Tunable parameters
        rangeThreshold double = 0.1          % Minimum range to process (meters)
        threatScoreStepness double = 0.4        
        speedScaleCutoff double = 5.0
        threatScoreThreshold double = 2.5         
    end

    methods
        function obj = EmergencyBrakeProcessor(radarConfig, maxDeceleration)
            % Constructor: Initialize with radar configuration and vehicle limits
            %
            % Inputs:
            %   radarConfig - RadarConfig object with system parameters
            %   maxDeceleration - Maximum brake deceleration capability (m/s²)

            arguments
                radarConfig RadarConfig
                maxDeceleration double {mustBePositive}
            end

            obj.maxDeceleration = maxDeceleration;
            obj.numRangeBins = radarConfig.NumRangeBins;
            obj.numDopplerBins = radarConfig.NumDopplerBins;
            obj.rangeIdxToMeters = radarConfig.RangeIdxToMeters;
            obj.dopplerResolutionMps = radarConfig.DopplerResolutionMps;
        end

        function [brakeForcePercent, threatInfo] = processDetections(obj, detections, tlvFrame)
            % Process CFAR detections and calculate required brake force
            %
            % Inputs:
            %   detections - [numRangeBins x numDopplerBins] boolean matrix from CFAR
            %   tlvFrame - TLVFrame object containing RangeDopplerProfile
            %
            % Outputs:
            %   brakeForcePercent - Brake force percentage [0-100]
            %   threatInfo - Struct with detection details for debugging/logging

            arguments
                obj EmergencyBrakeProcessor
                detections logical
                tlvFrame TLVFrame
            end

            % Initialize output
            brakeForcePercent = 0;
            threatInfo = struct('numGroups', 0, 'threats', []);

            % Validate inputs
            if isempty(detections) || ~any(detections(:)) || isempty(tlvFrame)|| isempty(tlvFrame.RangeDopplerProfile)
                obj.printBrakeCommand(0, 0);
                return;
            end

            % Step 1: Cluster detections using connected components
            groups = obj.clusterDetections(detections);

            % Step 2: Process each group
            maxThreat = 0;
            rangeDopplerProfile = tlvFrame.RangeDopplerProfile;

            for i = 1:groups.numGroups
                % Get current group mask
                groupMask = (groups.labels == i);

                % Step 3: Calculate weighted centroid
                [rangeMeters, velocityMps, weight] = obj.calculateWeightedCentroid(groupMask, rangeDopplerProfile);

                % Step 4: Filter by range threshold
                if rangeMeters < obj.rangeThreshold
                    continue; % Ignore detections too close (likely clutter)
                end

                % Step 5: Only process approaching objects (negative Doppler)
                % Note: Doppler axis is fftshifted, negative velocity = approaching
                if velocityMps >= 0
                    continue; % Ignore receding or stationary objects
                end

                % Step 6: Calculate threat score
                approachSpeed = abs(velocityMps); % Convert to positive for calculations
                threatScore = obj.calculateThreatScore(rangeMeters, approachSpeed);

                % Track maximum threat
                if threatScore > maxThreat
                    maxThreat = threatScore;
                end

                % Store threat info for debugging
                %threatInfo.threats(end+1) = struct(...
                %    'range', rangeMeters, ...
                %    'velocity', velocityMps, ...
                %    'weight', weight, ...
                %    'threatScore', threatScore);
            end

            % threatInfo.numGroups = groups.numGroups;

            % Step 7: Convert threat score to brake force percentage
            brakeForcePercent = min(maxThreat * 100, 100); % Clamp to [0, 100]
            deceleration = (brakeForcePercent / 100) * obj.maxDeceleration;

            % Step 8: Print brake command
            if deceleration > 0.1
                obj.printBrakeCommand(brakeForcePercent, deceleration);
            end
        end
    end

    methods (Static, Access = private)
        function groups = clusterDetections(detections)
            % Cluster adjacent detections using 2D connected components
            %
            % Input:
            %   detections - [numRangeBins x numDopplerBins] boolean matrix
            %
            % Output:
            %   groups - Struct with fields:
            %            .labels: [numRangeBins x numDopplerBins] label matrix
            %            .numGroups: Number of distinct groups

            arguments
                detections logical
            end

            % Use MATLAB's bwlabel for 2D connected component labeling
            % Connectivity = 8 (includes diagonal neighbors)
            [labelMatrix, numGroups] = bwlabel(detections, 8);

            groups = struct(...
                'labels', labelMatrix, ...
                'numGroups', numGroups);
        end

        function printBrakeCommand(brakeForcePercent, deceleration)
            % Display brake force command to console
            %
            % Inputs:
            %   brakeForcePercent - Brake force percentage [0-100]
            %   deceleration - Equivalent deceleration (m/s²)

            arguments
                brakeForcePercent double
                deceleration double
            end

            fprintf('[EMERGENCY BRAKE] Force: %.1f%% (%.2f m/s²)\n', ...
                brakeForcePercent, deceleration);
        end
    end

    methods (Access = private)
        function [rangeMeters, velocityMps, totalWeight] = calculateWeightedCentroid(obj, groupMask, rangeDopplerProfile)
            % Calculate signal-strength weighted centroid for a detection group
            %
            % Inputs:
            %   groupMask - [numRangeBins x numDopplerBins] logical mask for this group
            %   rangeDopplerProfile - [numRangeBins x numDopplerBins] uint16 intensity (log2 scale)
            %
            % Outputs:
            %   rangeMeters - Weighted centroid range in meters
            %   velocityMps - Weighted centroid velocity in m/s
            %   totalWeight - Sum of all weights (for debugging)

            arguments
                obj EmergencyBrakeProcessor
                groupMask logical
                rangeDopplerProfile
            end

            % Extract intensity values for this group
            % RangeDopplerProfile is uint16 in log2 scale, higher values = stronger signal
            intensities = double(rangeDopplerProfile(groupMask));

            % Use intensity as weights (already in log scale, so naturally compressed)
            weights = intensities;
            totalWeight = sum(weights);

            % Get indices of detection points in this group
            [rangeIndices, dopplerIndices] = find(groupMask);

            % Calculate weighted centroid in index space
            weightedRangeIdx = sum(rangeIndices .* weights) / totalWeight;
            weightedDopplerIdx = sum(dopplerIndices .* weights) / totalWeight;

            % Convert to physical units
            % Range: index to meters (1-based indexing, so subtract 1)
            rangeMeters = (weightedRangeIdx - 1) * obj.rangeIdxToMeters;

            % Doppler: Account for fftshift (zero velocity at center)
            % Doppler indices run from 1 to numDopplerBins
            % After fftshift: bin 1 = -maxVel, bin numDopplerBins/2 = 0, bin numDopplerBins = +maxVel
            dopplerCenterIdx = obj.numDopplerBins / 2 + 0.5; % Center is between bins for even N
            dopplerOffset = weightedDopplerIdx - dopplerCenterIdx;
            velocityMps = dopplerOffset * obj.dopplerResolutionMps;
        end

        function threatScore = calculateThreatScore(obj, rangeMeters, approachSpeedMps)
            % Calculate exponential threat score based on range and approach velocity
            %
            % Threat Model:
            %   - Closer objects = higher threat (exponential decay with distance)
            %   - Faster approach = higher threat (exponential increase with velocity)
            %   - Combined multiplicatively for compound effect
            %
            % Inputs:
            %   rangeMeters - Distance to object (meters)
            %   approachSpeedMps - Absolute approach velocity (m/s, positive)
            %
            % Output:
            %   threatScore - Normalized threat score [0, 1]

            arguments
                obj EmergencyBrakeProcessor
                rangeMeters double {mustBeNonnegative}
                approachSpeedMps double {mustBeNonnegative}
            end

            % Combined threat (both factors should be high for maximum threat)
            threatScore = 1/(1 + ...
                exp(-obj.threatScoreStepness*((approachSpeedMps*approachSpeedMps / rangeMeters) - obj.threatScoreThreshold)) ...
             *(1 - exp(obj.speedScaleCutoff * approachSpeedMps)) ...
             );

            % Ensure output is in [0, 1]
            threatScore = max(0, min(1, threatScore));
        end
    end
end
