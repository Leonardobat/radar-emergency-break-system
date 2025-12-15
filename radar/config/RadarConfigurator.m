classdef RadarConfigurator
    methods (Static)
        function [dataSerialPort, configSerialPort, radarConfig] = setup(configFilePath, configSerialPortPath, dataSerialPortPath)
            arguments (Input)
                configFilePath string
                configSerialPortPath string
                dataSerialPortPath string
            end
            arguments (Output)
                dataSerialPort
                configSerialPort
                radarConfig RadarConfig
            end
            
            try
                radarConfig = ConfigFileParser.parse(configFilePath);
                configSerialPort = serialport(configSerialPortPath, 115200);
                configureTerminator(configSerialPort, 'LF');
                
                dataSerialPort = serialport(dataSerialPortPath, 1152000, 'Timeout', 2);
                pause(1); % Wait for the radar to start up (?)
                flush(dataSerialPort);
                flush(configSerialPort);

                fprintf('Sending configuration to mmWave Radar...\n\nConfigFile:\n');
                
                isConfigSuccess = true;
                for i = 1:length(radarConfig.Config)
                    command = radarConfig.Config{i};
                    writeline(configSerialPort, command);
                    fprintf('%s\n', command);
                    
                    echo = readline(configSerialPort); % Get an echo of the command
                    fprintf('%s\n', echo);
                    
                    done = readline(configSerialPort); % Radar sends "Done" if the command was accepted
                    fprintf('%s\n', done);
                    
                    pause(0.1);
                    
                    % Check if command was accepted
                    %if ~contains(done, 'Done') && ~contains(command, 'configDataPort')
                        % If we get 'Debug', read one more line
                    if contains(done, 'Debug')
                        done = readline(configSerialPort);
                        fprintf('%s\n', done);
                        pause(0.01);
                        
                        if ~contains(done, 'Done')
                            isConfigSuccess = false;
                            fprintf('ERROR: Configuration failed at command %d: %s\n', i, command);
                            break;
                        end
                        %else
                        %    isConfigSuccess = false;
                        %    fprintf('ERROR: Configuration failed at command %d: %s\n', i, command);
                        %    break;
                        %end
                    end
                end
                
                % Check if configuration was successful
                if ~isConfigSuccess
                    % Clean up serial ports
                    if ~isempty(configSerialPort)
                        delete(configSerialPort);
                    end
                    if ~isempty(dataSerialPort)
                        delete(dataSerialPort);
                    end
                    error('Radar configuration failed. Check command sequence and radar connection.');
                end

                fprintf('\nConfiguration successful!\n');
                
            catch ME
                % Clean up in case of any error
                if ~isempty(configSerialPort)
                    writeline(configSerialPort, "sensorStop");
                    pause(0.05);
                    delete(configSerialPort);
                end
                if ~isempty(dataSerialPortPath)
                    delete(dataSerialPortPath);
                end
                rethrow(ME);
            end
        end

        function stopSensor(configSerialPort)
            arguments (Input)
                configSerialPort
            end
            
            if ~isempty(configSerialPort)
                writeline(configSerialPort, "sensorStop");
                pause(0.05);
            end
        end
    end
end