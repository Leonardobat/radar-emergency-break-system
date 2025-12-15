% The calculations comes from the mmWave SDK js implementation
% https://dev.ti.com/gallery/view/mmwave/mmWave_Demo_Visualizer/ver/3.6.0/

classdef RangeCFARProcessor
    properties (Access = private)
        trainCells = 6;
        guardCells = 2;
        probabilityOfFalseAlarm = 10e-2;
        numVirtAnt
        numRangeBins
        kernel
        alpha
    end

    methods
        function obj = RangeCFARProcessor(radarConfig, trainCells, guardCells)
            if nargin > 0
                obj.numVirtAnt = radarConfig.NumVirtAnt;
                obj.numRangeBins = radarConfig.NumRangeBins;
                obj.trainCells = trainCells;
                obj.guardCells = guardCells;
            end
            N = 2 * obj.trainCells;
            obj.alpha = N * (obj.probabilityOfFalseAlarm^(-1/N) - 1);
            kernel = ones(1, (2*obj.trainCells) + (2*obj.guardCells) + 1);
            kernel(obj.trainCells+1 : obj.trainCells+2*obj.guardCells+1) = 0; % Zero out the guard cells and CUT
            obj.kernel = kernel / N; % Normalize to calculate mean directly
        end
        
        function [detections, thresholdLine] = processData(obj, tvlFrame)
            if isempty(tvlFrame) || isempty(tvlFrame.RangeProfile)
                return;
            end

            % Calculate Noise Level for the whole vector at once
            % The 'same' argument clips the output to the size of rangeProfile
            noiseProfile = conv(tvlFrame.RangeProfile, obj.kernel, 'same');

            % Apply Threshold
            thresholdLine = noiseProfile * obj.alpha;

            % --- CRITICAL: EDGE HANDLING ---
            % We must ignore the edges where the kernel was "hanging off"
            % The number of invalid cells on each side is (Train + Guard)
            invalidRegion = obj.trainCells + obj.guardCells;

            % Set start edges to Infinity
            thresholdLine(1 : invalidRegion) = Inf;

            % Set end edges to Infinity
            thresholdLine(end - invalidRegion + 1 : end) = Inf;

            % 4. Detection
            detections = tvlFrame.RangeProfile > thresholdLine;
        end
    end
end