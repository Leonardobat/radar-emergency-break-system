% The calculations are done accordingly with the formulas
% provided in the doxygen documentation from mmWaveSDK version 3.06
% Some of the calculations comes from the mmWave SDK js implementation from
% https://dev.ti.com/gallery/view/mmwave/mmWave_Demo_Visualizer/ver/3.6.0/

classdef TLVFrameReader
    properties (Access = private, Constant)
        TLV_TAG_PLUS_SIZE_BYTES = 8
        SNR_MULTIPLIER = 0.1
        NOISE_MULTIPLIER = 0.1
        EXPECTED_MAGIC_WORD = [2,1,4,3,6,5,8,7];
    end

    properties (Access = private)
        radarConfig RadarConfig
        log2LinScale double
        dspFftScale double
    end

    methods
        function obj = TLVFrameReader(radarConfig)
            arguments (Input)
                radarConfig RadarConfig
            end
            arguments (Output)
                obj TLVFrameReader
            end

            obj.radarConfig = radarConfig;
            obj.log2LinScale = (1 / 512) * (...
                power(2,ceil(log2(double(obj.radarConfig.NumVirtAnt)))) /...
                double(obj.radarConfig.NumVirtAnt));
            obj.dspFftScale = 32 / double(obj.radarConfig.NumRangeBins);
        end

        function tlv = readTLVFrame(obj, dataPort)
            arguments (Input)
                obj TLVFrameReader
                dataPort
            end
            arguments (Output)
                tlv TLVFrame
            end

            if ~obj.findMagicWord(dataPort)
                tlv = TLVFrame();
                return;
            end

            tlvFrameHeader = parseTLVHeader(obj, dataPort);
            readSize = tlvFrameHeader.getSize();
            rangeProfile = [];
            noiseProfile = [];
            rangeDopplerProfile = [];
            detectedObjects = TLVDetectedObject.empty(1,0);
            statistics = TLVStatistics();
            detectedObjectsSideInfo = TLVDetectedObjectSideInfo.empty(1, 0);
            for i = 1:tlvFrameHeader.NumTLVs(1)
                tag = read(dataPort, 1, 'uint32');    % Structure tag (4bytes)
                size = read(dataPort, 1, 'uint32');   % Length of structure (4bytes)
                readSize = readSize + size + obj.TLV_TAG_PLUS_SIZE_BYTES;

                switch(tag)
                    case TLVTag.DetectedObjects
                        detectedObjects = obj.parseDetectedObjects(tlvFrameHeader.NumDetectedObj, dataPort);
                    case TLVTag.RangeProfile
                        rangeProfile = obj.parseRangeProfile(dataPort);
                    case TLVTag.NoiseProfile
                        noiseProfile = obj.parseNoiseProfile(dataPort);
                    case TLVTag.RangeDopplerProfile
                        rangeDopplerProfile = obj.parseRangeDoppler(dataPort);
                    case TLVTag.Statistics
                        statistics = obj.parseStatistics(dataPort);
                    case TLVTag.DetectedObjectsSideInfo
                        detectedObjectsSideInfo = ...
                            obj.parseSideInfoPacket(tlvFrameHeader.NumDetectedObj, dataPort);
                    case TLVTag.Temperature
                        temperature = obj.parseTemperature(dataPort);
                    otherwise
                        break
                end
            end
            tlv = TLVFrame(...
                tlvFrameHeader,...
                rangeProfile,...
                noiseProfile,...
                detectedObjects,...
                rangeDopplerProfile,...
                statistics,...
                detectedObjectsSideInfo...
                );
            obj.readPadding(dataPort, tlvFrameHeader.PacketLength, readSize);
        end
    end

    methods (Access = private)
        function found = findMagicWord(obj, dataPort)
            arguments (Input)
                obj TLVFrameReader
                dataPort
            end
            arguments (Output)
                found logical
            end

            maxSearchBytes = 1000; % Limit search to prevent infinite loop
            buffer = zeros(1, 8);

            for i = 1:maxSearchBytes
                % Shift buffer and read new byte
                buffer = [buffer(2:end), read(dataPort, 1, 'uint8')];

                % Check if buffer matches magic word
                if isequal(buffer, obj.EXPECTED_MAGIC_WORD)
                    if i > 8
                        fprintf('Warning: Magic word not found in first 8 bytes. Found at byte %d\n', i);
                    end
                    found = true;
                    return;
                end
                if i == 8
                    fprintf('Warning: Magic word not found in first 8 bytes\n');
                end
            end

            found = false;
        end

        function tlvFrameHeader = parseTLVHeader(obj, dataPort)
            arguments (Input)
                obj TLVFrameReader
                dataPort
            end
            arguments (Output)
                tlvFrameHeader TLVFrameHeader
            end

            version = read(dataPort, 4, 'uint8');
            packetLength = read(dataPort, 1, 'uint32');
            platform = read(dataPort, 4, 'uint8');
            frameNumber = read(dataPort, 4, 'uint8');
            timeCpuCycles = read(dataPort, 4, 'uint8');
            numDetectedObj = read(dataPort, 1, 'uint32');
            numTLVs = read(dataPort, 1, 'uint32');
            numCurrentSubFrame = read(dataPort, 1, 'uint32');

            tlvFrameHeader = TLVFrameHeader(...
                version,...
                packetLength,...
                platform,...
                frameNumber,...
                timeCpuCycles,...
                numDetectedObj,...
                numTLVs,...
                numCurrentSubFrame...
                );
        end

        function tlvDetectedObjects = parseDetectedObjects(obj, numDetectedObj, dataPort)
            arguments (Input)
                obj TLVFrameReader
                numDetectedObj
                dataPort
            end
            arguments (Output)
                tlvDetectedObjects TLVDetectedObject
            end
            tlvDetectedObjects = TLVDetectedObject.empty(1, 0);
            for i = 1:numDetectedObj
                x = read(dataPort, 1, 'single');
                y = read(dataPort, 1, 'single');
                z = read(dataPort, 1, 'single');
                doppler = read(dataPort, 1, 'single');

                tlvDetectedObjects(i) = TLVDetectedObject(x, y, z, doppler);
            end
        end

        function tlvRangeProfile = parseRangeProfile(obj, dataPort)
            arguments (Input)
                obj TLVFrameReader
                dataPort
            end
            arguments (Output)
                tlvRangeProfile
            end
            bins = obj.radarConfig.NumRangeBins;
            rangeProfile = read(dataPort, bins, 'uint16');
            tlvRangeProfile = obj.dspFftScale * power(2, rangeProfile * obj.log2LinScale);
        end

        function tlvNoiseProfile = parseNoiseProfile(obj, dataPort)
            arguments (Input)
                obj TLVFrameReader
                dataPort
            end
            arguments (Output)
                tlvNoiseProfile
            end
            bins = obj.radarConfig.NumRangeBins;
            noiseProfile = read(dataPort, bins, 'uint16');
            tlvNoiseProfile = obj.dspFftScale * power(2, noiseProfile * obj.log2LinScale);
        end

        function tlvRangeDopplerProfile = parseRangeDoppler(obj, dataPort)
            arguments (Input)
                obj TLVFrameReader
                dataPort
            end
            arguments (Output)
                tlvRangeDopplerProfile
            end
            bins = obj.radarConfig.NumRangeBins * obj.radarConfig.NumDopplerBins;
            rangeDopplerProfile = read(dataPort, bins, 'uint16');

            tlvRangeDopplerProfile = obj.dspFftScale * power(2, rangeDopplerProfile * obj.log2LinScale);

            tlvRangeDopplerProfile = reshape(tlvRangeDopplerProfile,...
                obj.radarConfig.NumDopplerBins,...
                obj.radarConfig.NumRangeBins).';

            tlvRangeDopplerProfile = fftshift(tlvRangeDopplerProfile, 2);
        end

        function tlvStatistics = parseStatistics(obj, dataPort)
            arguments (Input)
                obj TLVFrameReader
                dataPort
            end
            arguments (Output)
                tlvStatistics TLVStatistics
            end
            interframeProcessTime = read(dataPort, 1, 'uint32');
            transmitOutputTime = read(dataPort, 1, 'uint32');
            interframeProcessMargin = read(dataPort, 1, 'uint32');
            interchirpProcessMargin = read(dataPort, 1, 'uint32');
            activeFrameCpuLoad = read(dataPort, 1, 'uint32');
            interframeCpuLoad = read(dataPort, 1, 'uint32');
            tlvStatistics = TLVStatistics(...
                interframeProcessTime,...
                transmitOutputTime,...
                interframeProcessMargin,...
                interchirpProcessMargin,...
                activeFrameCpuLoad,...
                interframeCpuLoad...
                );
        end

        function tlvTemperature = parseTemperature(obj, dataPort)
            arguments (Input)
                obj TLVFrameReader
                dataPort
            end
            arguments (Output)
                tlvTemperature
            end
            tlvTemperature.tempReportValid = read(dataPort,1,'uint32');
            tlvTemperature.time = read(dataPort,1,'uint32');
            tlvTemperature.tmpRx0Sens = read(dataPort,1,'uint16');
            tlvTemperature.tmpRx1Sens = read(dataPort,1,'uint16');
            tlvTemperature.tmpRx2Sens = read(dataPort,1,'uint16');
            tlvTemperature.tmpRx3Sens = read(dataPort,1,'uint16');
            tlvTemperature.tmpTx0Sens = read(dataPort,1,'uint16');
            tlvTemperature.tmpTx1Sens = read(dataPort,1,'uint16');
            tlvTemperature.tmpTx2Sens = read(dataPort,1,'uint16');
            tlvTemperature.tmpPmSens = read(dataPort,1,'uint16');
            tlvTemperature.tmpDig0Sens = read(dataPort,1,'uint16');
            tlvTemperature.tmpDig1Sens = read(dataPort,1,'uint16');
        end

        function sideInfos = parseSideInfoPacket(obj, numDetectedObj, dataPort)
            arguments (Input)
                obj TLVFrameReader
                numDetectedObj
                dataPort
            end
            arguments (Output)
                sideInfos TLVDetectedObjectSideInfo
            end
            sideInfos = TLVDetectedObjectSideInfo.empty(1, 0);
            for i = 1:numDetectedObj
                snrRaw = read(dataPort, 1, 'int16');
                snr = snrRaw * obj.SNR_MULTIPLIER;
                noiseRaw = read(dataPort, 1, 'int16');
                noise = noiseRaw * obj.NOISE_MULTIPLIER;
                sideInfos(i) = TLVDetectedObjectSideInfo(snr, noise);
            end
        end


        % The end of the packet is padded so that the total packet length is always multiple of 32 Bytes.
        function readPadding(obj, dataPort, packetLength, readSize)
            arguments (Input)
                obj TLVFrameReader
                dataPort
                packetLength
                readSize
            end
            padding = packetLength - readSize;
            if padding > 0
                read(dataPort, padding, 'uint8');
            end
        end
    end
end