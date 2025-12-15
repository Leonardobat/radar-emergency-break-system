classdef PlotRangeDopplerCFARUI < RadarPlot
    properties (Access = private)
        plotHandle
        numRangeBins
        numDopplerBins
        rangeAxis
        dopplerAxis
    end

    methods
        function obj = PlotRangeDopplerCFARUI(radarConfig)
            % 1. Extract dimensions and resolution
            obj.numRangeBins = radarConfig.NumRangeBins;
            obj.numDopplerBins = radarConfig.NumDopplerBins;

            % 2. Calculate Axes
            N = radarConfig.NumRangeBins;
            plotResolution = radarConfig.RangeIdxToMeters;
            obj.rangeAxis = 0:plotResolution:(N*plotResolution)-plotResolution;
            maxRange = N*plotResolution;

            % Doppler axis centered at 0
            obj.dopplerAxis = (-obj.numDopplerBins/2 : (obj.numDopplerBins/2 - 1)) * radarConfig.DopplerResolutionMps;

            % 3. Create Figure and Image object
            obj.figureHandle = figure('Name', 'Range-Doppler Heatmap With CA-CFAR');
            ax = axes(obj.figureHandle);
            hold(ax, 'on');
            obj.plotHandle = gobjects(1,2);

            % Initialize with zeros: Rows = Doppler, Cols = Range
            obj.plotHandle(1) = imagesc(ax, obj.rangeAxis, obj.dopplerAxis,...
                zeros(obj.numDopplerBins, obj.numRangeBins));
            % CFAR detections overlay
            obj.plotHandle(2) = scatter(ax, NaN, NaN, 30, 'w',...
               'filled', 'MarkerEdgeColor', 'k');

            % 4. Formatting
            % axis xy; % Ensure Y-axis increases upwards
            xlim(ax, [0 maxRange]);
            xlabel(ax, "Range (meters)");
            ylabel(ax, "Velocity (m/s)");
            title(ax, "Realtime Range-Doppler Map");
            colorbar(ax);
            colormap(ax, jet);
            legend(ax, 'Location', 'northeast');
            grid(ax, 'on');
            clim(ax, [62, 78]);
        end

        function updatePlot(obj, data)
            % Ensure the specific data exists in the frame
            if nargin < 2 || isempty(data); return; end
                rangeDopplerProfile = data{1};
                detections = data{2};

            % --- Update Plot ---
            % We transpose rdMap back to (D, R) for the image YData/XData alignment
            dbProfile = 20 * log10(rangeDopplerProfile + eps); 
            obj.plotHandle(1).CData = dbProfile.';

            if any(detections(:))

               [rIdx, dIdx] = find(detections);

               ranges = obj.rangeAxis(rIdx);
               velocities = obj.dopplerAxis(dIdx);

               obj.plotHandle(2).XData = ranges;
               obj.plotHandle(2).YData = velocities;
           else
               obj.plotHandle(2).XData = NaN;
               obj.plotHandle(2).YData = NaN;
           end

            drawnow('limitrate');
        end
    end
end