classdef PlotRangeUI < RadarPlot
    properties (Access = private)
        plotHandle
        numVirtAnt
        numRangeBins
        
    end

    methods
        function obj = PlotRangeUI(radarConfig)
            arguments (Input)
                radarConfig RadarConfig
            end
            arguments (Output)
                obj PlotRangeUI
            end
            obj.numVirtAnt = radarConfig.NumVirtAnt;
            obj.numRangeBins = radarConfig.NumRangeBins;

            N = radarConfig.NumRangeBins;
            plotResolution = radarConfig.RangeIdxToMeters;
            plotRange = 0:plotResolution:(N*plotResolution)-plotResolution;
            maxRange = N*plotResolution;

            % Create figure + line object
            obj.figureHandle = figure('Name', 'Range Profile');
            obj.plotHandle = plot(plotRange, zeros(1, N), 'b', plotRange, zeros(1, N), 'r');
            xlim([0 maxRange])
            xlabel("Range (meters)");
            ylabel("Magnitude (dB)");
            title("Realtime Range & Noise");
            grid on;
        end

        function updatePlot(obj, tvlFrame)
            arguments
                obj PlotRangeUI
                tvlFrame
            end

            if isempty(tvlFrame) || isempty(tvlFrame.RangeProfile)
                return;
            end

            % Update plot
            dbRangeProfile = 20 * log10(tvlFrame.RangeProfile + eps); 
            dbNoiseProfile = 20 * log10(tvlFrame.NoiseProfile + eps); 
            obj.plotHandle(1).YData = dbRangeProfile;
            obj.plotHandle(2).YData = dbNoiseProfile;

            drawnow('limitrate');
        end
    end
end