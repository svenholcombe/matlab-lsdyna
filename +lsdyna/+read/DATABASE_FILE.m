classdef DATABASE_FILE < handle
    %DATABASE_FILE Superclass for all LS-DYNA ascii database file readers
    
    properties (Transient)
        folder
        source
    end
    properties (Abstract)
        file
    end
    properties (Constant, Hidden)
        storageMatFile = 'lsdyna.database.mat'
        sciNumRegexpPattern = '[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?';
    end
    properties (Hidden)
        storageMatFileLastRead
    end
    properties (Dependent, Hidden)
        asciiFullfile
        storageMatFullfile
    end
    methods %% Utility methods
        function x = get.asciiFullfile(this)
            x = fullfile(this.folder, this.file);
        end
        function x = get.storageMatFullfile(this)
            x = fullfile(this.folder, this.storageMatFile);
        end
    end
    methods (Abstract, Hidden) %% Required for any child classes to implement
        parseFileContents(this, inStr)
        addDerivedDataChannels(this)
    end
    
    methods
        % Constructor, called by all children:
        % this = this@lsdyna.read.DATABASE_FILE(varargin{:});
        function this = DATABASE_FILE(inputFolder,varargin)
            
            % Accept a directory (or file) to look for
            if exist(inputFolder,'dir')
                this.folder = inputFolder;
            elseif exist(inputFolder,'file')
                [this.folder,b,c] = fileparts(inputFolder);
                this.file = [b c];
            else
                warning('File %s does not exist - attempting to load from .mat file',inputFolder)
                this.folder = fileparts(inputFolder);
            end
            
            % By default presume we need to load from ascii
            loadFromMatFile = false;
            % Check for a previously saved .mat file
            [savedObj, lastReadDate] = loadMatContents(this);
            
            % Check if there's an ascii file to load (or compare dates)
            if exist(this.asciiFullfile,'file') && ~isempty(savedObj)
                asciiMeta = dir(this.asciiFullfile);
                if ~isempty(lastReadDate) && lastReadDate>datetime(asciiMeta.date)
                    loadFromMatFile = true;
                end
            else % No ascii file - just rely on .mat file
                if ~isempty(savedObj)
                    loadFromMatFile = true;
                end
            end
            
            if loadFromMatFile
                mc = metaclass(savedObj);
                for i = 1:length(mc.PropertyList)
                    prop = mc.PropertyList(i);
                    % Ignore Transient properties like the folder
                    % name (which will be empty when saved)
                    if prop.Transient || prop.NonCopyable
                        continue;
                    end
                    this.(prop.Name) = savedObj.(prop.Name);
                end
                this.source = 'mat';
            else % Resort to a load from ascii
                if exist(this.asciiFullfile,'file')
                    this.readAscii;
                    this.source = 'ascii';
                else
                    warning('File not found: %s\n',this.asciiFullfile)
                    return;
                end
            end
            
            % Append any derived data fields
            this.addDerivedDataChannels();
        end
        function save(this)
            preSaveFile = this.storageMatFullfile;
            fprintf('Saving %s to %s...', this.file, preSaveFile)
            if exist(preSaveFile,'file')
                saveStruct = load(preSaveFile);
            else
                saveStruct = struct();
            end
            saveStruct.(this.file) = this; %#ok<STRNU>
            save(preSaveFile, '-struct', 'saveStruct')
            fprintf(' done.\n')
        end
        function [objFromMat, lastReadDate] = loadMatContents(this)
            
            lastReadDate = datetime('01-01-1900','InputFormat','dd-MM-yyyy');
            objFromMat = [];
            % Check for the presence of a pre-saved .mat file to load from
            preSaveFile = this.storageMatFullfile;
            if exist(preSaveFile,'file')
                % Check if this particular database file is pre-saved
                savedObjs = whos('-file',preSaveFile);
                if any(strcmp(this.file,{savedObjs.name}))
                    % Attempt to load from .mat file and not ascii file
                    fprintf('Loading %s from %s...', this.file, preSaveFile)
                    tmp = load(preSaveFile, this.file);
                    fprintf(' done.\n')
                    % We now have loaded object. Copy its copy-able props
                    objFromMat = tmp.(this.file);
                    % Extract the last date this object was saved
                    try
                        lastReadDate = objFromMat.storageMatFileLastRead;
                    catch ME
                        warning(ME.message)
                    end
                end
            end
        end
        function readAscii(this)
            fprintf('Loading %s from %s...', this.file, this.asciiFullfile)
            inStr = fileread(this.asciiFullfile);
            this.parseFileContents(inStr)
            this.storageMatFileLastRead = datetime('now');
            fprintf(' done.\n')
            this.source = 'ascii';
        end
        function replaceAscii(this)
            this.save
            this.deleteAscii;
        end
        function deleteAscii(this)
            % Remove the ascii file if requested
            if exist(this.asciiFullfile,'file')
                delete(this.asciiFullfile)
            end
        end
    end
end