classdef Radar < handle
    properties (Access = private)
        tlvFrameReader TLVFrameReader
        dataSerialPort
        configSerialPort
    end

    properties (Access = public)
        radarConfig RadarConfig
    end

    methods
        function obj = Radar(configFilePath, configSerialPortPath, dataSerialPortPath)
            arguments (Input)
                configFilePath string
                configSerialPortPath string
                dataSerialPortPath string
            end
            arguments (Output)
                obj Radar
            end

            % Load configuration & Setup radar
            [dataSerialPort, configSerialPort, radarConfig] = RadarConfigurator.setup(configFilePath, configSerialPortPath, dataSerialPortPath);
            obj.radarConfig = radarConfig;
            obj.dataSerialPort = dataSerialPort;
            obj.configSerialPort = configSerialPort;
            obj.tlvFrameReader = TLVFrameReader(radarConfig);
        end

        function frame = readData(obj)
            arguments (Input)
                obj Radar
            end
            arguments (Output)
                frame TLVFrame
            end
            frame = obj.tlvFrameReader.readTLVFrame(obj.dataSerialPort);
        end

        function delete(obj)
            % Cleanup when object is destroyed
            if ~isempty(obj.dataSerialPort) && isvalid(obj.dataSerialPort)
                obj.stop();
                delete(obj.dataSerialPort);
                disp('Radar serial port closed.');
            end
        end

        function stop(obj)
            % Cleanup when object is destroyed
            if ~isempty(obj.dataSerialPort) && isvalid(obj.dataSerialPort)
                RadarConfigurator.stopSensor(obj.configSerialPort);
                disp('Radar serial sensor stopped.');
            end
        end
    end
    

    methods (Static)
        function obj = withUI()
            % Create radar instance using UI for configuration
            ui = RadarSetupUI();
            [configFile, configPort, dataPort, cancelled] = ui.getSelections();
            
            if cancelled
                error('radar:setup:Cancelled', 'Radar setup cancelled by user');
            end
            
            obj = Radar(configFile, configPort, dataPort);
        end
    end
end