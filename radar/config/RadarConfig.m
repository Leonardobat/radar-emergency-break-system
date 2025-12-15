classdef RadarConfig
    % RADARCONFIG Data Transfer Object for radar configuration
    
    properties (SetAccess = immutable)
        Config
        % Channel Configuration
        NumTxAnt int8
        NumRxAnt int8
        NumVirtAnt int8
        TxChannelEn int8
        RxChannelEn int8
        
        % Profile Configuration
        StartFreqGHz double
        IdleTimeUs double
        RampEndTimeUs double
        FreqSlopeConst double
        NumAdcSamples double
        DigOutSampleRate double
        
        % Frame Configuration
        ChirpStartIdx int64
        ChirpEndIdx int64
        NumLoops int64
        NumFrames int64
        FramePeriodicity double
        
        % Derived Parameters
        NumChirpsPerFrame double
        NumDopplerBins double
        NumRangeBins double
        RangeResolutionMeters double
        RangeIdxToMeters double
        DopplerResolutionMps double
        MaxRange double
        MaxVelocity double
    end
    
    methods
        function obj = RadarConfig(config, channelCfg, profileCfg, frameCfg, derivedParams)  
            % TODO: Add validation logic for properties
            obj.Config = config;
            % Channel config
            obj.NumTxAnt = channelCfg.numTxAnt;
            obj.NumRxAnt = channelCfg.numRxAnt;
            obj.NumVirtAnt = channelCfg.numTxAnt * channelCfg.numRxAnt;
            obj.TxChannelEn = channelCfg.txChannelEn;
            obj.RxChannelEn = channelCfg.rxChannelEn;
            
            % Profile config
            obj.StartFreqGHz = profileCfg.startFreq;
            obj.IdleTimeUs = profileCfg.idleTime;
            obj.RampEndTimeUs = profileCfg.rampEndTime;
            obj.FreqSlopeConst = profileCfg.freqSlopeConst;
            obj.NumAdcSamples = profileCfg.numAdcSamples;
            obj.DigOutSampleRate = profileCfg.digOutSampleRate;
            
            % Frame config
            obj.ChirpStartIdx = frameCfg.chirpStartIdx;
            obj.ChirpEndIdx = frameCfg.chirpEndIdx;
            obj.NumLoops = frameCfg.numLoops;
            obj.NumFrames = frameCfg.numFrames;
            obj.FramePeriodicity = frameCfg.framePeriodicity;
            
            % Derived parameters
            obj.NumChirpsPerFrame = derivedParams.numChirpsPerFrame;
            obj.NumDopplerBins = derivedParams.numDopplerBins;
            obj.NumRangeBins = derivedParams.numRangeBins;
            obj.RangeResolutionMeters = derivedParams.rangeResolutionMeters;
            obj.RangeIdxToMeters = derivedParams.rangeIdxToMeters;
            obj.DopplerResolutionMps = derivedParams.dopplerResolutionMps;
            obj.MaxRange = derivedParams.maxRange;
            obj.MaxVelocity = derivedParams.maxVelocity;
        end
        
        function disp(obj)
            % Custom display method
            fprintf('RadarConfig:\n');
            fprintf('  Antennas: %d Tx, %d Rx, %d Virtual\n', ...
                obj.NumTxAnt, obj.NumRxAnt, obj.NumVirtAnt);
            fprintf('  Range: %.2f m (resolution: %.3f m)\n', ...
                obj.MaxRange, obj.RangeResolutionMeters);
            fprintf('  Velocity: %.2f m/s (resolution: %.3f m/s)\n', ...
                obj.MaxVelocity, obj.DopplerResolutionMps);
            fprintf('  Bins: %d range, %d Doppler\n', ...
                obj.NumRangeBins, obj.NumDopplerBins);
        end
    end
end