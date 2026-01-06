classdef RadarRunner < handle
    properties (Access = private)
        radar
        rangeCfarProcessor RangeCFARProcessor
        rangeDopplerCfarProcessor RangeDopplerCFARProcessor
        emergencyBrakeProcessor EmergencyBrakeProcessor
        plotUI
        plotStatisticsUI
        pollingTimer
        isRunning logical
        isRecording logical = false
        recordedFrames = {}
    end
    
    methods
        function obj = RadarRunner()
            obj.isRunning = false;
        end
        
        function enableRecording(obj)
            disp('Starting to log frames');
            obj.isRecording = true;
            obj.recordedFrames = {};
        end
        
        function start(obj, dataFile)
            try
                if nargin > 1 && ischar(dataFile)
                    fprintf('Initializing File Playback...\n');
                    obj.radar = MockRadar(dataFile, 'profile_range.cfg');
                else
                     fprintf('Starting Radar Setup...\n');
                    obj.radar = Radar.withUI();
                end


                fprintf('Initializing CFAR Processor...\n');
                obj.rangeCfarProcessor = RangeCFARProcessor(obj.radar.radarConfig, 6, 2);
                obj.rangeDopplerCfarProcessor = RangeDopplerCFARProcessor(obj.radar.radarConfig, 6, 2, 6, 2);

                fprintf('Initializing Emergency Brake Processor...\n');
                maxDeceleration = 9.8; % m/s² (1g deceleration)
                obj.emergencyBrakeProcessor = EmergencyBrakeProcessor(obj.radar.radarConfig, maxDeceleration);

                fprintf('Initializing visualization...\n');
                obj.plotStatisticsUI = PlotStatisticsUI(100);
                obj.plotUI = PlotRangeDopplerCFARUI(obj.radar.radarConfig);

                obj.plotUI.onClose(@() obj.stop());
                
                obj.setupTimer();
                
                start(obj.pollingTimer);
                obj.isRunning = true;

                fprintf('Radar runner started successfully!\n');
                fprintf('Close the plot window to stop.\n');
                
            catch ME
                if strcmp(ME.identifier, 'radar:setup:Cancelled')
                    fprintf('Radar setup cancelled by user.\n');
                else
                    fprintf('Error starting radar: %s\n', ME.message);
                    rethrow(ME);
                end
            end
        end
        
        function stop(obj)
            if obj.isRunning && ~isempty(obj.pollingTimer)
                stop(obj.pollingTimer);
                delete(obj.pollingTimer);
                obj.radar.stop();
                obj.plotUI.delete();
                obj.plotStatisticsUI.delete();
                obj.isRunning = false;
                fprintf('Radar runner stopped.\n');
            end

            if obj.isRecording && ~isempty(obj.recordedFrames)
                frames = obj.recordedFrames; % local copy for saving
                save('radar_session_log.mat', 'frames');
                fprintf('Saved %d frames to radar_session_log.mat\n', length(frames));
            end
        end
        
        function delete(obj)
            % Cleanup when object is destroyed
            obj.stop();
        end
    end
    
    methods (Access = private)
        function setupTimer(obj)
        % Use 'fixedSpacing' to prevent overlapping execution
            obj.pollingTimer = timer( ...
                'ExecutionMode', 'fixedSpacing', ... 
                'Period', 0.001, ... % Small delay between executions
                'BusyMode', 'drop', ... % If busy, skip the next execution
                'TimerFcn', @(~,~) obj.pollAndProcessData() ...
            );
        end
        
        function pollAndProcessData(obj)
            try
                tlvFrame = obj.radar.readData();
                
                if isempty(tlvFrame) || ~tlvFrame.isValid()
                    return;
                end
                
                detections = obj.rangeDopplerCfarProcessor.processData(tlvFrame);

                obj.emergencyBrakeProcessor.processDetections(detections, tlvFrame);

                data = {tlvFrame.RangeDopplerProfile, detections};

                obj.plotUI.updatePlot(data);
                obj.plotStatisticsUI.updatePlot(tlvFrame);

                if obj.isRecording
                    obj.recordedFrames{end+1} = tlvFrame;
                end
                
                drawnow limitrate;
            catch ME
                fprintf("Error updating plot:\n%s\n", ME.getReport('extended', 'hyperlinks', 'off'));
                obj.stop();
            end
        end
    end
    
    methods (Static)
        function run(dataLogging)
            isLogEnabled = false;
            if nargin > 0
                isLogEnabled = dataLogging;
            end    
            runner = RadarRunner();
            
            if isLogEnabled
                runner.enableRecording();
            end
            
            runner.start();
            assignin('base', 'radarRunner', runner);
        end
    end
end