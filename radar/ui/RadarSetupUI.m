classdef RadarSetupUI < handle
    properties (Access = private)
        figure
        configFileEdit
        configPortDropdown
        dataPortDropdown
        startButton
        cancelButton
        selectedConfig
        selectedConfigPort
        selectedDataPort
        userCancelled
    end
    
    methods
        function obj = RadarSetupUI()
            obj.userCancelled = false;
            obj.createUI();
        end
        
        function [configFile, configPort, dataPort, cancelled] = getSelections(obj)
            % Wait for user to make selections
            uiwait(obj.figure);
            
            configFile = obj.selectedConfig;
            configPort = obj.selectedConfigPort;
            dataPort = obj.selectedDataPort;
            cancelled = obj.userCancelled;
        end
    end
    
    methods (Access = private)
        function createUI(obj)
            % Create figure
            obj.figure = uifigure('Name', 'Radar Setup', ...
                'Position', [100 100 500 300], ...
                'Resize', 'off');
            
            % Create grid layout
            grid = uigridlayout(obj.figure, [5 3]);
            grid.RowHeight = {'fit', 'fit', 'fit', '1x', 'fit'};
            grid.ColumnWidth = {'fit', '1x', 'fit'};
            grid.Padding = [20 20 20 20];
            grid.RowSpacing = 15;
            
            % Configuration file selection
            uilabel(grid, 'Text', 'Config File:', ...
                'HorizontalAlignment', 'right');
            obj.configFileEdit = uieditfield(grid, 'text', ...
                'Value', 'profile_range.cfg', ...
                'Editable', false);
            obj.configFileEdit.Layout.Row = 1;
            obj.configFileEdit.Layout.Column = 2;
            
            browseBtn = uibutton(grid, 'Text', 'Browse...', ...
                'ButtonPushedFcn', @(~,~) obj.browseConfigFile());
            browseBtn.Layout.Row = 1;
            browseBtn.Layout.Column = 3;
            
            % Config serial port selection
            uilabel(grid, 'Text', 'Config Port:', ...
                'HorizontalAlignment', 'right');
            availablePorts = obj.getAvailablePorts();
            obj.configPortDropdown = uidropdown(grid, ...
                'Items', availablePorts, ...
                'Value', availablePorts{1});
            obj.configPortDropdown.Layout.Row = 2;
            obj.configPortDropdown.Layout.Column = [2 3];
            
            % Data serial port selection
            uilabel(grid, 'Text', 'Data Port:', ...
                'HorizontalAlignment', 'right');
            obj.dataPortDropdown = uidropdown(grid, ...
                'Items', availablePorts, ...
                'Value', availablePorts{min(2, length(availablePorts))});
            obj.dataPortDropdown.Layout.Row = 3;
            obj.dataPortDropdown.Layout.Column = [2 3];
            
            % Buttons
            buttonGrid = uigridlayout(grid, [1 3]);
            buttonGrid.Layout.Row = 5;
            buttonGrid.Layout.Column = [1 3];
            buttonGrid.ColumnWidth = {'1x', 'fit', 'fit'};
            buttonGrid.ColumnSpacing = 10;
            
            uilabel(buttonGrid); % Spacer
            
            obj.startButton = uibutton(buttonGrid, 'Text', 'Start', ...
                'ButtonPushedFcn', @(~,~) obj.onStart());
            
            obj.cancelButton = uibutton(buttonGrid, 'Text', 'Cancel', ...
                'ButtonPushedFcn', @(~,~) obj.onCancel());
        end
        
        function ports = getAvailablePorts(~)
            % Get list of available serial ports
            try
                portInfo = serialportlist("available");
                if isempty(portInfo)
                    ports = {'No ports available'};
                else
                    ports = cellstr(portInfo);
                end
            catch
                ports = {'Error detecting ports'};
            end
        end
        
        function browseConfigFile(obj)
            % Open file browser for config file selection
            [file, path] = uigetfile({'*.cfg', 'Config Files (*.cfg)'}, ...
                'Select Configuration File', ...
                fullfile(pwd, 'configs'));
            
            if file ~= 0
                obj.configFileEdit.Value = fullfile(path, file);
            end
        end
        
        function onStart(obj)
            % Validate selections
            if strcmp(obj.configPortDropdown.Value, obj.dataPortDropdown.Value)
                uialert(obj.figure, ...
                    'Config port and data port must be different!', ...
                    'Invalid Selection');
                return;
            end
            
            if contains(obj.configPortDropdown.Value, 'No ports') || ...
               contains(obj.dataPortDropdown.Value, 'No ports')
                uialert(obj.figure, ...
                    'Please select valid serial ports!', ...
                    'Invalid Selection');
                return;
            end
            
            % Store selections
            obj.selectedConfig = obj.configFileEdit.Value;
            obj.selectedConfigPort = obj.configPortDropdown.Value;
            obj.selectedDataPort = obj.dataPortDropdown.Value;
            obj.userCancelled = false;
            
            % Close UI
            uiresume(obj.figure);
            delete(obj.figure);
        end
        
        function onCancel(obj)
            obj.userCancelled = true;
            uiresume(obj.figure);
            delete(obj.figure);
        end
    end
end