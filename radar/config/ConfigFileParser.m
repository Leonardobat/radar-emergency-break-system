% All calculations are done accordingly with the formulas
% provided in the doxygen documentation from mmWaveSDK version 3.06
classdef ConfigFileParser
    % CONFIGPARSER Parse radar configuration files

    properties (Constant)
        DEFAULT_CONFIG = 'profile_range.cfg'
        SPEED_OF_LIGHT = 3e8   % m/s
    end

    methods (Static)
        function radarConfig = parse(configFile)
            arguments (Input)
                configFile string
            end
            arguments (Output)
                radarConfig RadarConfig
            end
            % Parse configuration file and calculate parameters
            fullPath = ConfigFileParser.resolveConfigPath(configFile);
            config = ConfigFileParser.readFile(fullPath);
            [channelCfg, profileCfg, frameCfg] = ConfigFileParser.extractConfigs(config);
            params = ConfigFileParser.calculateParameters(channelCfg, profileCfg, frameCfg);
            radarConfig = RadarConfig(config, channelCfg, profileCfg, frameCfg, params);
        end
    end

    methods (Static, Access = private)
        function fullPath = resolveConfigPath(configFile)
            arguments (Input)
                configFile string
            end
            arguments (Output)
                fullPath string
            end
            % Resolve configuration file path (works cross-platform)
            % Supports:
            %   - Absolute paths
            %   - Relative paths from current directory
            %   - Filenames only (searches in config directory)

            % Check if it's already an absolute path
            if ConfigFileParser.isAbsolutePath(configFile)
                fullPath = configFile;
                if ~isfile(fullPath)
                    error('radar:config:FileNotFound', ...
                        'Configuration file not found: %s', fullPath);
                end
                return;
            end

            % Try relative to current directory first
            if isfile(configFile)
                fullPath = configFile;
                return;
            end

            % Get the directory where this class file is located
            classFilePath = mfilename('fullpath');
            [classDir, ~, ~] = fileparts(classFilePath);

            % Try in the same directory as this class (radar/config/)
            fullPath = fullfile(classDir, configFile);
            if isfile(fullPath)
                return;
            end

            % Try in project root configs directory
            projectRoot = fileparts(fileparts(classDir)); % Go up two levels
            fullPath = fullfile(projectRoot, 'configs', configFile);
            if isfile(fullPath)
                return;
            end

            % File not found anywhere
            error('radar:config:FileNotFound', ...
                'Configuration file not found: %s\nSearched in:\n  - Current directory\n  - %s\n  - %s', ...
                configFile, classDir, fullfile(projectRoot, 'configs'));
        end

        function config = readFile(configFile)
            arguments (Input)
                configFile string
            end
            arguments (Output)
                config cell
            end

            % Read configuration file into cell array
            % Ignores lines starting with '%' (comments)
            config = cell(1, 100);
            conf_file = fopen(configFile, 'r');

            if conf_file == -1
                error('radar:config:CannotOpenFile', ...
                    'Cannot open file: %s', configFile);
            end

            fprintf('Opening configuration file %s ...\n', configFile);

            tline = fgetl(conf_file);
            i = 1;
            while ischar(tline)
                % Trim whitespace
                trimmedLine = strtrim(tline);

                % Skip empty lines and comment lines (starting with '%')
                if ~isempty(trimmedLine) && ~startsWith(trimmedLine, '%')
                    config{i} = tline;
                    i = i + 1;
                end

                tline = fgetl(conf_file);
            end

            fclose(conf_file);

            % Trim empty cells
            config = config(1:i-1);
        end


        function [channelCfg, profileCfg, frameCfg] = extractConfigs(config)
            arguments (Input)
                config cell
            end
            arguments (Output)
                channelCfg struct
                profileCfg struct
                frameCfg struct
            end

            for i=1:length(config)
                configLine=strsplit(config{i});
                if strcmp(configLine{1},'channelCfg')
                    channelCfg.txChannelEn = str2double(configLine{3});
                    channelCfg.numTxAzimAnt = bitand(bitshift(channelCfg.txChannelEn,0),1)+bitand(bitshift(channelCfg.txChannelEn,-2),1);
                    channelCfg.numTxElevAnt = bitand(bitshift(channelCfg.txChannelEn,-1),1);
                    channelCfg.rxChannelEn = str2double(configLine{2});
                    channelCfg.numRxAnt = bitand(bitshift(channelCfg.rxChannelEn,0),1)+bitand(bitshift(channelCfg.rxChannelEn,-1),1)+bitand(bitshift(channelCfg.rxChannelEn,-2),1)+bitand(bitshift(channelCfg.rxChannelEn,-3),1);
                    channelCfg.numTxAnt = channelCfg.numTxElevAnt+channelCfg.numTxAzimAnt;
                elseif strcmp(configLine{1},'profileCfg')
                    profileCfg.startFreq = str2double(configLine{3});
                    profileCfg.idleTime = str2double(configLine{4});
                    profileCfg.rampEndTime = str2double(configLine{6});
                    profileCfg.freqSlopeConst = str2double(configLine{9});
                    profileCfg.numAdcSamples = str2double(configLine{11});
                    profileCfg.numAdcSamplesRoundTo2 = 1;
                    while profileCfg.numAdcSamples>profileCfg.numAdcSamplesRoundTo2
                        profileCfg.numAdcSamplesRoundTo2=profileCfg.numAdcSamplesRoundTo2*2;
                    end
                    profileCfg.digOutSampleRate = str2double(configLine{12});
                elseif strcmp(configLine{1},'frameCfg')
                    frameCfg.chirpStartIdx = str2double(configLine{2});
                    frameCfg.chirpEndIdx = str2double(configLine{3});
                    frameCfg.numLoops = str2double(configLine{4});
                    frameCfg.numFrames = str2double(configLine{5});
                    frameCfg.framePeriodicity = str2double(configLine{6});
                end
            end
        end

        function params = calculateParameters(channelCfg, profileCfg, frameCfg)
            arguments (Input)
                channelCfg struct
                profileCfg struct
                frameCfg struct
            end
            arguments (Output)
                params struct
            end

            c = ConfigFileParser.SPEED_OF_LIGHT;
            params.numChirpsPerFrame = frameCfg.numLoops * (...
                frameCfg.chirpEndIdx - frameCfg.chirpStartIdx + 1 ...
                );
            
            params.numDopplerBins = params.numChirpsPerFrame / channelCfg.numTxAnt;
            
            params.numRangeBins = profileCfg.numAdcSamplesRoundTo2;

            params.rangeResolutionMeters = c * profileCfg.digOutSampleRate * 1e3 / ...
                (2.0 * profileCfg.freqSlopeConst * 1e12 * profileCfg.numAdcSamples);
            
            params.rangeIdxToMeters = c * profileCfg.digOutSampleRate * 1e3 / ...
                (2.0 * profileCfg.freqSlopeConst * 1e12 * params.numRangeBins);
            
            params.dopplerResolutionMps = c / ...
                (2.0 * profileCfg.startFreq * 1e9 * (...
                        profileCfg.idleTime + profileCfg.rampEndTime...
                    ) * 1e-6 * params.numDopplerBins*channelCfg.numTxAnt...
                );
            
            params.maxRange = 300 * 0.9 * profileCfg.digOutSampleRate /...
                (2.0 * profileCfg.freqSlopeConst * 1e3);
            
            params.maxVelocity = c /...
                (4.0 * profileCfg.startFreq * 1e9 * (...
                    profileCfg.idleTime+profileCfg.rampEndTime...
                    ) * 1e-6 * channelCfg.numTxAnt...
                );
            
            params.numVirtAnt = channelCfg.numTxAnt * channelCfg.numRxAnt;
        end

        function result = isAbsolutePath(path)
            arguments (Input)
                path string
            end
            arguments (Output)
                result logical
            end

            % Check if path is absolute (cross-platform)
            if ispc
                % Windows: Check for drive letter (C:\) or UNC path (\\)
                result = ~isempty(regexp(path, '^[A-Za-z]:\\', 'once')) || ...
                    startsWith(path, '\\');
            else
                % Unix/Linux/Mac: Check for leading /
                result = startsWith(path, '/');
            end
        end
    end
end
