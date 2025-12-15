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
        
        % Call this before calling start() if you want to save data
        function enableRecording(obj)
            disp('Starting to log frames');
            obj.isRecording = true;
            obj.recordedFrames = {}; % Clear buffer
        end
        
        function start(obj, dataFile)
            try
                if nargin > 1 && ischar(dataFile)
                    % --- OFFLINE MODE ---
                    fprintf('Initializing File Playback...\n');
                    obj.radar = MockRadar(dataFile, 'profile_range_for_log1.cfg'); % true = loop data
                else
                    % --- LIVE MODE ---
                    % Initialize radar with UI setup
                     fprintf('Starting Radar Setup...\n');
                    obj.radar = Radar.withUI();
                end


                % Initialize CFAR processor with radar config
                fprintf('Initializing CFAR Processor...\n');
                obj.rangeCfarProcessor = RangeCFARProcessor(obj.radar.radarConfig, 6, 2);
                obj.rangeDopplerCfarProcessor = RangeDopplerCFARProcessor(obj.radar.radarConfig, 4, 1, 4, 1);

                % Initialize Emergency Brake Processor
                fprintf('Initializing Emergency Brake Processor...\n');
                maxDeceleration = 9.8; % m/s² (1g deceleration)
                obj.emergencyBrakeProcessor = EmergencyBrakeProcessor(obj.radar.radarConfig, maxDeceleration);

                % Create plot UI
                fprintf('Initializing visualization...\n');
                % obj.plotUI = PlotRangeCFARUI(obj.radar.radarConfig);
                % obj.plotUI = PlotRangeDopplerUI(obj.radar.radarConfig);
                obj.plotStatisticsUI = PlotStatisticsUI(100);
                obj.plotUI = PlotRangeDopplerCFARUI(obj.radar.radarConfig);

                % Register close figure callback
                obj.plotUI.onClose(@() obj.stop());
                
                % Setup timer for continuous updates
                obj.setupTimer();
                
                % Start the timer
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
                % Read data from radar
                tlvFrame = obj.radar.readData();
                
                % Check if valid frame was received
                if isempty(tlvFrame) || ~tlvFrame.isValid()
                    return;
                end
                
                % Apply CFAR processing to data to get object detections
                % [detections, thresholdLine] = obj.rangeCfarProcessor.processData(tlvFrame);
                % data = {tlvFrame.RangeProfile, thresholdLine, detections};

                detections = obj.rangeDopplerCfarProcessor.processData(tlvFrame);

                % Emergency brake processing
                [brakeForce, threatInfo] = obj.emergencyBrakeProcessor.processDetections(detections, tlvFrame);

                data = {tlvFrame.RangeDopplerProfile, detections};

                % Update plot
                obj.plotUI.updatePlot(data);
                obj.plotStatisticsUI.updatePlot(tlvFrame);

                if obj.isRecording
                    obj.recordedFrames{end+1} = tlvFrame;
                end
                
                drawnow limitrate;
            catch ME
                % Handle errors gracefully
                fprintf("Error updating plot:\n%s\n", ME.getReport('extended', 'hyperlinks', 'off'));
                obj.stop();
            end
        end
    end
    
    methods (Static)
        function run(dataLogging)
            isLogginEnabled = false;
            if nargin > 0
                isLogginEnabled = dataLogging;
            end    
            % Convenience static method to create and start runner
            runner = RadarRunner();
            
            if isLogginEnabled
                runner.enableRecording();
            end
            
            runner.start();

            % Keep runner in base workspace to prevent garbage collection
            assignin('base', 'radarRunner', runner);
        end
    end
end