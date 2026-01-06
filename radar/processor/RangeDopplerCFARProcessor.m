classdef RangeDopplerCFARProcessor
    properties (Access = private)
        % Window dimensions (one side)
        trainR, guardR
        trainD, guardD
        
        probFalseAlarm = 1e-4;
        numRangeBins
        numDopplerBins
        
        alpha     % Threshold scaling factor
        numTrain  % Total number of training cells
    end
    
    methods
        function obj = RangeDopplerCFARProcessor(radarConfig, Tr, Gr, Td, Gd)
            obj.numRangeBins   = radarConfig.NumRangeBins;
            obj.numDopplerBins = radarConfig.NumDopplerBins;
            obj.trainR = Tr; obj.guardR = Gr;
            obj.trainD = Td; obj.guardD = Gd;
            
            fullSideR = 2*(Tr + Gr) + 1;
            fullSideD = 2*(Td + Gd) + 1;
            innerSideR = 2*Gr + 1;
            innerSideD = 2*Gd + 1;
            
            obj.numTrain = (fullSideR * fullSideD) - (innerSideR * innerSideD);
            
            obj.alpha = obj.numTrain * (obj.probFalseAlarm^(-1/obj.numTrain) - 1);
        end
        
        function detections = processData(obj, tvlFrame)
            if isempty(tvlFrame) || isempty(tvlFrame.RangeDopplerProfile)
                detections = false(obj.numRangeBins, obj.numDopplerBins);
                return;
            end
            
            RD = tvlFrame.RangeDopplerProfile;
            
            kernelTotal = ones(2*(obj.trainR + obj.guardR) + 1, 2*(obj.trainD + obj.guardD) + 1);
            
            kernelInner = ones(2*obj.guardR + 1, 2*obj.guardD + 1);
            
            sumTotal = conv2(RD, kernelTotal, 'same');
            sumInner = conv2(RD, kernelInner, 'same');
            
            sumTrain = sumTotal - sumInner;
            noiseAverage = sumTrain / obj.numTrain;
            
            threshold = noiseAverage * obj.alpha;
            rawDetections = RD > threshold;
            
            offsetR = obj.trainR + obj.guardR;
            offsetD = obj.trainD + obj.guardD;
            
            validMask = false(size(RD));
            validMask(offsetR+1 : end-offsetR, offsetD+1 : end-offsetD) = true;
            
            detections = rawDetections & validMask;
        end
    end
end