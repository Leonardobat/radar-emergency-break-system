classdef PlotStatisticsUI < RadarPlot
    properties (Access = private)
        timingPlotHandle
        cpuLoadPlotHandle
        marginPlotHandle
        bufferSize
        frameCounter
        
        % Data buffers
        interframeProcessTimeBuffer
        transmitOutputTimeBuffer
        activeFrameCpuLoadBuffer
        interframeCpuLoadBuffer
        interframeProcessMarginBuffer
    end

    methods
        function obj = PlotStatisticsUI(bufferSize)
            arguments (Input)
                bufferSize (1,1) double = 100
            end
            arguments (Output)
                obj PlotStatisticsUI
            end
            
            obj.bufferSize = bufferSize;
            obj.frameCounter = 0;
            
            % Initialize buffers
            obj.interframeProcessTimeBuffer = zeros(1, bufferSize);
            obj.transmitOutputTimeBuffer = zeros(1, bufferSize);
            obj.activeFrameCpuLoadBuffer = zeros(1, bufferSize);
            obj.interframeCpuLoadBuffer = zeros(1, bufferSize);
            obj.interframeProcessMarginBuffer = zeros(1, bufferSize);
            
            % Create figure with 3 subplots
            obj.figureHandle = figure('Name', 'TLV Statistics');
            
            % Subplot 1: Timing (usec)
            subplot(3, 1, 1);
            obj.timingPlotHandle = plot(1:bufferSize, zeros(1, bufferSize), 'b', ...
                                        1:bufferSize, zeros(1, bufferSize), 'r');
            xlabel("Frame Sequence");
            ylabel("Time (msec)");
            title("Processing Timing");
            legend('Interframe Process Time', 'Transmit Output Time');
            grid on;
            
            % Subplot 2: CPU Load (%)
            subplot(3, 1, 2);
            obj.cpuLoadPlotHandle = plot(1:bufferSize, zeros(1, bufferSize), 'g', ...
                                         1:bufferSize, zeros(1, bufferSize), 'm');
            xlabel("Frame Sequence");
            ylabel("CPU Load (%)");
            title("CPU Load");
            legend('Active Frame CPU Load', 'Interframe CPU Load');
            grid on;
            ylim([0 100]);
            
            % Subplot 3: Margin (usec)
            subplot(3, 1, 3);
            obj.marginPlotHandle = plot(1:bufferSize, zeros(1, bufferSize), 'b');
            xlabel("Frame Sequence");
            ylabel("Margin (msec)");
            title("Interframe Process Margin");
            grid on;
        end

        function updatePlot(obj, tlvFrame)
            arguments
                obj PlotStatisticsUI
                tlvFrame
            end

            if isempty(tlvFrame) || isempty(tlvFrame.Statistics) || tlvFrame.Statistics.isEmpty()
                return;
            end

            stats = tlvFrame.Statistics;
            
            % Shift buffers and add new data
            obj.interframeProcessTimeBuffer = [obj.interframeProcessTimeBuffer(2:end), stats.InterframeProcessTime / 1000];
            obj.transmitOutputTimeBuffer = [obj.transmitOutputTimeBuffer(2:end), stats.TransmitOutputTime / 1000];
            obj.activeFrameCpuLoadBuffer = [obj.activeFrameCpuLoadBuffer(2:end), stats.ActiveFrameCpuLoad];
            obj.interframeCpuLoadBuffer = [obj.interframeCpuLoadBuffer(2:end), stats.InterframeCpuLoad];
            obj.interframeProcessMarginBuffer = [obj.interframeProcessMarginBuffer(2:end), stats.InterframeProcessMargin / 1000];
            
            obj.frameCounter = obj.frameCounter + 1;
            
            % Update timing plot
            obj.timingPlotHandle(1).YData = obj.interframeProcessTimeBuffer;
            obj.timingPlotHandle(2).YData = obj.transmitOutputTimeBuffer;
            
            % Update CPU load plot
            obj.cpuLoadPlotHandle(1).YData = obj.activeFrameCpuLoadBuffer;
            obj.cpuLoadPlotHandle(2).YData = obj.interframeCpuLoadBuffer;
            
            % Update margin plot
            obj.marginPlotHandle.YData = obj.interframeProcessMarginBuffer;
            
            drawnow('limitrate');
        end
    end
end