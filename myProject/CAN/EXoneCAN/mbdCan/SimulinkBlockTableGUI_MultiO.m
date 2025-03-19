function SimulinkBlockTableGUI_MultiO
   % Create the GUI figure
fig = uifigure('Position', [100, 100, 950, 500], 'Name', 'Simulink Block Selector - Multi Model');

% UI Components for Model Selection
lblModel = uilabel(fig, 'Text', 'Loaded Models:', 'Position', [20, 470, 150, 30]);
lstModels = uilistbox(fig, 'Position', [20, 420, 310, 20]); % List of loaded models
btnLoadModel = uibutton(fig, 'Text', 'Load Model', 'Position', [150, 470, 100, 25], 'ButtonPushedFcn', @(btn, event) loadModel());
btnClearModel = uibutton(fig, 'Text', 'Clear Model', 'Position', [260, 470, 100, 25], 'ButtonPushedFcn', @(btn, event) clearModel());

    % Block Type Selection Table (Now Below Model Name)
    lblTypeTable = uilabel(fig, 'Text', 'Select Block Types:', 'Position', [20, 350, 150, 30]);
    tblTypes = uitable(fig, 'Position', [20, 250, 320, 100]); 
    tblTypes.ColumnName = {'Select', 'Block Type', 'Total Count'};
    tblTypes.ColumnEditable = [true, false, false];

    % Blocks Table (Moved Below)
    lblBlockTable = uilabel(fig, 'Text', 'Blocks of Selected Types:', 'Position', [20, 70, 250, 30]);
    tblBlocks = uitable(fig, 'Position', [20, 10, 900, 140]); 
    tblBlocks.ColumnName = {'Sr. No.', 'Model', 'Block Type', 'Block Name', 'Path', 'Input Type', 'Output Type'};

    % Total Blocks Label (Moved Parallel to Block Selection Label)
    lblTotal = uilabel(fig, 'Text', 'Total Blocks: 0', 'Position', [600, 220, 200, 30], 'FontWeight', 'bold');

    % Variables
    loadedModels = {};  
    blockTypeGroups = containers.Map();

    %% Function to Load Simulink Model
    function loadModel()
        [file, path] = uigetfile('*.slx', 'Select Simulink Model');
        if isequal(file, 0)
            return;
        end

        modelFile = fullfile(path, file);
        modelName = erase(file, '.slx'); 

        if ismember(modelName, loadedModels)
            uialert(fig, 'Model already loaded!', 'Duplicate Model');
            return;
        end

        try
            if ~bdIsLoaded(modelName)
                load_system(modelFile);
            end
            loadedModels{end+1} = modelName;
            lstModels.Items = loadedModels;
            listModelBlocks(modelName);
        catch ME
            disp(['Error loading model: ' ME.message]);
        end
    end

   %% Function to Clear Selected Model
function clearModel()
    selectedModel = lstModels.Value;
    if isempty(selectedModel)
        return;
    end

    % Remove model from loaded list
    loadedModels(strcmp(loadedModels, selectedModel)) = [];
    lstModels.Items = loadedModels;

    % Remove model's blocks and types from blockTypeGroups
    blockTypesToRemove = keys(blockTypeGroups);
    for i = 1:length(blockTypesToRemove)
        blockData = blockTypeGroups(blockTypesToRemove{i});
        blockData = blockData(~strcmp(blockData(:, 1), selectedModel), :);

        if isempty(blockData)
            remove(blockTypeGroups, blockTypesToRemove{i});
        else
            blockTypeGroups(blockTypesToRemove{i}) = blockData;
        end
    end

    % Reset Block Type Selection Table (Clear the Table)
    tblTypes.Data = {};  % Clear block types table

    % Reset Block Details Table and Deselect all Block Types
    tblBlocks.Data = {};  % Clear blocks table
    lblTotal.Text = 'Total Blocks: 0';  % Reset total block count

    % Reset Block Type Selection and Deselect All Types
    tblTypes.Data(:, 1) = {false};  % Deselect all block types

    % Update tables to reflect the changes
    updateBlockDetails();
end


    %% Function to List Blocks for Each Model
    function listModelBlocks(modelName)
        if isempty(modelName)
            return;
        end
        
        try
            if ~bdIsLoaded(modelName)
                load_system(modelName);
            end
            
            allBlocks = find_system(modelName, 'Type', 'Block');
            totalBlockCount = length(allBlocks);
            lblTotal.Text = ['Total Blocks: ', num2str(totalBlockCount)];
            
            for i = 1:length(allBlocks)
                blockName = get_param(allBlocks{i}, 'Name');
                blockType = get_param(allBlocks{i}, 'BlockType');
                blockPath = allBlocks{i};

                % Retrieve input & output data types
                try
                    inDataType = get_param(allBlocks{i}, 'CompiledPortDataTypes');
                    inType = inDataType.Inport; % Input Data Type
                    outType = inDataType.Outport; % Output Data Type
                catch
                    inType = 'N/A'; 
                    outType = 'N/A'; 
                end

                % Store block data
                blockData = {modelName, blockType, blockName, blockPath, inType, outType};
                
                if isKey(blockTypeGroups, blockType)
                    blockTypeGroups(blockType) = [blockTypeGroups(blockType); blockData];
                else
                    blockTypeGroups(blockType) = blockData;
                end
            end
            
            % Populate Block Type Selection Table with Block Count
            blockTypes = keys(blockTypeGroups);
            blockCounts = cellfun(@(x) size(blockTypeGroups(x), 1), blockTypes);
            tableData = [num2cell(false(size(blockTypes)))', blockTypes', num2cell(blockCounts)'];
            tblTypes.Data = tableData;
            tblTypes.CellEditCallback = @(src, event) updateBlockDetails();
            
            updateBlockDetails();
        catch ME
            disp(['Error listing blocks: ' ME.message]);
        end
    end

    %% Function to Update Block Details Based on Selection
    function updateBlockDetails()
        if isempty(tblTypes.Data)
            return;
        end

        % Get selected types
        selectedTypes = tblTypes.Data([tblTypes.Data{:, 1}] == true, 2); % Extract selected types
        if isempty(selectedTypes)
            tblBlocks.Data = {};
            lblTotal.Text = 'Total Blocks: 0';
            return;
        end

        % Prepare the block data to display in the table
        allData = {};
        for i = 1:length(selectedTypes)
            if isKey(blockTypeGroups, selectedTypes{i})
                typeData = blockTypeGroups(selectedTypes{i});
                for j = 1:size(typeData, 1)
                    allData = [allData; {size(allData, 1) + 1, typeData{j, 1}, selectedTypes{i}, typeData{j, 2}, typeData{j, 3}, typeData{j, 4}, typeData{j, 5}}]; %#ok<AGROW>
                end
            end
        end

        tblBlocks.Data = allData;
        lblTotal.Text = ['Total Blocks: ', num2str(size(allData, 1))];
    end
end
