classdef MockRadar < handle
    properties
        frames
        radarConfig
        currentIndex = 1
    end
    
    methods
        function obj = MockRadar(filename, configFilePath)
            data = load(filename);
            obj.frames = data.frames;
            % The config must be the same as used on the recording!!!
            obj.radarConfig = ConfigFileParser.parse(configFilePath);
        end
        
        function tlvFrame = readData(obj)
            if obj.currentIndex <= length(obj.frames)
                tlvFrame = obj.frames{obj.currentIndex};
                obj.currentIndex = obj.currentIndex + 1;
                
                % slow down playback to match real-time
                pause(0.05); 
            else
                tlvFrame = []; % Signals end of stream
                fprintf('End of recorded file reached.\n');
            end
        end
        
        function stop(~)
            % No hardware to stop
        end
    end
end