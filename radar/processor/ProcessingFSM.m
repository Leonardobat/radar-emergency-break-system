classdef ProcessingFSM
    properties (Access = private)
        state ProcessingState
        buffer TLVFrame
    end

    methods
        function obj = ProcessingFSM()
            obj.state = ProcessingState();
            obj.buffer = TLVFrame.empty(1,0);
        end

        function [result, obj] = processEvent(obj, tlvFrame)
            result = TLVFrame.empty(1,0);
            switch (obj.state.stateType)
                case ProcessingStateType.Warmup
                    % The start counter is in the cell 1,1
                    obj.state.counters{1,1} = obj.state.counters{1,1} + 1;
                    startStateCounter = obj.state.counters{1,1};
                    if startStateCounter <= 10
                        obj.buffer(startStateCounter) = tlvFrame;
                        return;
                    else
                        % Process data and transition to state 1
                        rangeProfiles = zeros(length(obj.buffer(1).RangeProfile), 10);
                        for i = 1:10
                            rangeProfiles(:, i) = obj.buffer(i).RangeProfile;
                        end
                        obj.state.clutterAverage = mean(rangeProfiles, 2);
                    end
            
                case ProcessingStateType.Detection
                    % Apply clutter removal
                    % TODO: think if we need to reset the clutter after some time.
                    if ~isempty(obj.state.clutterAverage) && ~isempty(tlvFrame.RangeProfile)
                        cleanedProfile = tlvFrame.RangeProfile - obj.state.clutterAverage;
                        % TODO: treat correctly the negative values
                        % cleanedProfile(cleanedProfile < 0) = 0;

                        % TODO: Use the cleaned profile for the CFAR algorithm to detect objects

                        % TODO: Implement the "emergency detection" feature
                        
                        % Create result frame with cleaned data
                        result = TLVFrame(...
                            tlvFrame.Header, ...
                            cleanedProfile, ...
                            tlvFrame.NoiseProfile, ...
                            tlvFrame.DetectedObjects, ...
                            tlvFrame.Statistics, ...
                            tlvFrame.DetectedObjectsSideInfo ...
                        );
                    end
                
            otherwise
                return;
            end
        end
    end
end