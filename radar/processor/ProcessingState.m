classdef ProcessingState
    properties (Access = private)
        stateType ProcessingStateType
        counters cell
        clutterAverage double
    end

    methods (Access = private)
        function obj = ProcessingState(state, counters, clutterAverage)
            if nargin > 0
                obj.stateType = state;
                obj.counters = counters;
                obj.clutterAverage = clutterAverage;
            end

            obj.stateType = ProcessingStateType.Warmup;
            obj.counters = cell();
            obj.clutterAverage = [];
        end
    end
end