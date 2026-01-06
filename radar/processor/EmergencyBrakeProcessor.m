classdef EmergencyBrakeProcessor
    properties (Access = private)
        maxDeceleration double
        numRangeBins
        numDopplerBins
        rangeIdxToMeters double
        dopplerResolutionMps double

        rangeThreshold double = 0.1
        threatScoreSteepness double = 0.4
        speedScaleCutoff double = 5.0
        threatScoreThreshold double = 2.5
    end

    methods
        function obj = EmergencyBrakeProcessor(radarConfig, maxDeceleration)
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
            arguments
                obj EmergencyBrakeProcessor
                detections logical
                tlvFrame TLVFrame
            end

            brakeForcePercent = 0;
            threatsTemplate = struct('range', {}, 'velocity', {}, 'weight', {}, 'threatScore', {}, 'ttc', {});
            threatInfo = struct('numGroups', 0, 'threats', threatsTemplate);

            if isempty(detections) || ~any(detections(:)) || isempty(tlvFrame)|| isempty(tlvFrame.RangeDopplerProfile)
                return;
            end

            groups = obj.clusterDetections(detections);

            maxThreat = 0;
            maxThreatIdx = 0;

            rangeDopplerProfile = tlvFrame.RangeDopplerProfile;
            for i = 1:groups.numGroups
                groupMask = (groups.labels == i);

                [rangeMeters, velocityMps, weight] = obj.calculateWeightedCentroid(groupMask, rangeDopplerProfile);
                if rangeMeters < obj.rangeThreshold || velocityMps >= 0
                    continue;
                end


                approachSpeed = abs(velocityMps);
                threatScore = obj.calculateThreatScore(rangeMeters, approachSpeed);

                % Calculate Time-to-Collision (seconds)
                % Using a tiny epsilon (1e-6) to prevent division by zero
                ttc = rangeMeters / max(approachSpeed, 1e-6);

                % Store threat info for debugging
                threatInfo.threats(end+1) = struct(...
                    'range', rangeMeters, ...
                    'velocity', velocityMps, ...
                    'weight', weight, ...
                    'threatScore', threatScore,...
                    'ttc', ttc);

                if threatScore > maxThreat
                    maxThreat = threatScore;
                    maxThreatIdx = numel(threatInfo.threats);
                end
            end

            threatInfo.numGroups = groups.numGroups;

            if maxThreatIdx > 0
                target = threatInfo.threats(maxThreatIdx);

                brakeForcePercent = min(maxThreat * 100, 100);
                deceleration = (brakeForcePercent / 100) * obj.maxDeceleration;

                if deceleration > 0.1
                    obj.printBrakeCommand(brakeForcePercent, deceleration, ...
                        target);
                end
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

        function printBrakeCommand(brakeForcePercent, deceleration, target)
            % Display brake force command to console
            %
            % Inputs:
            %   brakeForcePercent - Brake force percentage [0-100]
            %   deceleration - Equivalent deceleration (m/s²)
            %   target - Struct with the target that triggered the braking

            arguments
                brakeForcePercent double
                deceleration double
                target struct
            end
            fprintf('[EMERGENCY BRAKE] Force: %.1f%% (%.2f m/s²) | Obj: %.1fm @ %.3fm/s | TTC: %.2fs | Score: %.2f\n', ...
                brakeForcePercent, deceleration, target.range,...
                abs(target.velocity), target.ttc, target.threatScore);
        end
    end

    methods (Access = private)
        function [rangeMeters, velocityMps, totalWeight] = calculateWeightedCentroid(obj, groupMask, rangeDopplerProfile)
            arguments
                obj EmergencyBrakeProcessor
                groupMask logical
                rangeDopplerProfile
            end

            intensities = double(rangeDopplerProfile(groupMask));

            weights = intensities;
            totalWeight = sum(weights);

            [rangeIndices, dopplerIndices] = find(groupMask);

            weightedRangeIdx = sum(rangeIndices .* weights) / totalWeight;
            weightedDopplerIdx = sum(dopplerIndices .* weights) / totalWeight;

            rangeMeters = (weightedRangeIdx - 1) * obj.rangeIdxToMeters;

            dopplerCenterIdx = obj.numDopplerBins / 2 + 0.5; % Center is between bins for even N
            dopplerOffset = weightedDopplerIdx - dopplerCenterIdx;
            velocityMps = dopplerOffset * obj.dopplerResolutionMps;
        end

        function threatScore = calculateThreatScore(obj, rangeMeters, approachSpeedMps)

            arguments
                obj EmergencyBrakeProcessor
                rangeMeters double {mustBeNonnegative}
                approachSpeedMps double {mustBeNonnegative}
            end

            metric = (approachSpeedMps^2 / rangeMeters);
            threatScore = (1/...
                ( ...
                1 + exp(-obj.threatScoreSteepness*(metric - obj.threatScoreThreshold)) ...
                ) ...
                )...
                * (1 - exp(-obj.speedScaleCutoff * approachSpeedMps));

            threatScore = max(0, min(1, threatScore));
        end
    end
end
