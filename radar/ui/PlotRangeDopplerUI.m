classdef PlotRangeDopplerUI < RadarPlot
    properties (Access = private)
        plotHandle
        numRangeBins
        numDopplerBins
        rangeAxis
        dopplerAxis
    end

    methods
        function obj = PlotRangeDopplerUI(radarConfig)
            % 1. Extract dimensions and resolution
            obj.numRangeBins = radarConfig.NumRangeBins;
            obj.numDopplerBins = radarConfig.NumDopplerBins;
            
            % 2. Calculate Axes
            N = radarConfig.NumRangeBins;
            plotResolution = radarConfig.RangeIdxToMeters;
            plotRange = 0:plotResolution:(N*plotResolution)-plotResolution;
            maxRange = N*plotResolution;
            
            % Doppler axis centered at 0
            obj.dopplerAxis = (-obj.numDopplerBins/2 : (obj.numDopplerBins/2 - 1)) * radarConfig.DopplerResolutionMps;
            
            % 3. Create Figure and Image object
            obj.figureHandle = figure('Name', 'Range-Doppler Heatmap');
            % Initialize with zeros: Rows = Doppler, Cols = Range
            obj.plotHandle = imagesc(plotRange, obj.dopplerAxis, zeros(obj.numDopplerBins, obj.numRangeBins));
            
            % 4. Formatting
            axis xy; % Ensure Y-axis increases upwards
            xlim([0 maxRange])
            xlabel("Range (meters)");
            ylabel("Velocity (m/s)");
            title("Realtime Range-Doppler Map");
            colorbar;
            colormap(jet); 
            grid on;
        end

        function updatePlot(obj, tlvFrame)
            % Ensure the specific data exists in the frame
            if isempty(tlvFrame) || isempty(tlvFrame.RangeDopplerProfile)
                return;
            end
            
            % --- Update Plot ---
            % We transpose rdMap back to (D, R) for the image YData/XData alignment
            dbRangeDopplerProfile = 20 * log10(rangeDopplerProfile + eps); 
            obj.plotHandle(1).CData = dbRangeDopplerProfile.';
            
            drawnow('limitrate');
        end
    end
end