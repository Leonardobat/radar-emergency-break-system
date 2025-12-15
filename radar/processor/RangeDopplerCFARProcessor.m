classdef RangeDopplerCFARProcessor
    properties (Access = private)
        % Window dimensions (one side)
        trainR, guardR
        trainD, guardD
        
        Pfa = 0.25;
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
            
            % Total number of training cells in the 2D rectangular ring
            % (Full Window Area) - (Guard + CUT Area)
            fullSideR = 2*(Tr + Gr) + 1;
            fullSideD = 2*(Td + Gd) + 1;
            innerSideR = 2*Gr + 1;
            innerSideD = 2*Gd + 1;
            
            obj.numTrain = (fullSideR * fullSideD) - (innerSideR * innerSideD);
            
            % CA-CFAR Alpha calculation for Square Law Detector
            obj.alpha = obj.numTrain * (obj.Pfa^(-1/obj.numTrain) - 1);
        end
        
        function detections = processData(obj, tvlFrame)
            if isempty(tvlFrame) || isempty(tvlFrame.RangeDopplerProfile)
                detections = false(obj.numRangeBins, obj.numDopplerBins);
                return;
            end
            
            RD = tvlFrame.RangeDopplerProfile;
            
            % 1. Create Convolution Kernels
            % kernelTotal: sum of everything including training, guards, and CUT
            kernelTotal = ones(2*(obj.trainR + obj.guardR) + 1, 2*(obj.trainD + obj.guardD) + 1);
            
            % kernelInner: sum of only the guards and the CUT
            kernelInner = ones(2*obj.guardR + 1, 2*obj.guardD + 1);
            
            % 2. Calculate Noise Power using 2D Convolution
            % 'same' padding returns result of the same size as RD
            sumTotal = conv2(RD, kernelTotal, 'same');
            sumInner = conv2(RD, kernelInner, 'same');
            
            % sumTrain is the sum of noise in the training cells only
            sumTrain = sumTotal - sumInner;
            noiseAverage = sumTrain / obj.numTrain;
            
            % 3. Detection Thresholding
            threshold = noiseAverage * obj.alpha;
            rawDetections = RD > threshold;
            
            % 4. Boundary Masking
            % Zero-padding in conv2 makes noise estimates near edges unreliable.
            % We create a logical mask that is only true for the "valid" interior.
            offsetR = obj.trainR + obj.guardR;
            offsetD = obj.trainD + obj.guardD;
            
            validMask = false(size(RD));
            validMask(offsetR+1 : end-offsetR, offsetD+1 : end-offsetD) = true;
            
            % Final result: Point must exceed threshold AND be within valid window
            detections = rawDetections & validMask;
        end
    end
end