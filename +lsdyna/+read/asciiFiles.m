classdef asciiFiles < dynamicprops
    %ASCIIFILES Read all available LS-DYNA output databases
    %
    % out = lsdyna.read.asciiFiles(folder)
    %
    % out = 
    %   asciiFiles with properties:
    % 
    %     folder: 'C:\Folder\Holding\Simulation'
    %     rbdout: [1x1 lsdyna.read.rbdout]
    %     nodfor: [1x1 lsdyna.read.nodfor]
    %     bndout: [1x1 lsdyna.read.bndout]
    %     nodout: [1x1 lsdyna.read.nodout]
    %      elout: [1x1 lsdyna.read.elout]
    
    properties (Transient)
        folder
    end
    
    methods
        function this = asciiFiles(inputFolder, varargin)
            
            IP = inputParser;
            IP.addParameter('replace', false)
            IP.parse(varargin{:})
            opts = IP.Results;
            
            % Accept a directory (or file) to look for
            if exist(inputFolder,'dir')
                this.folder = inputFolder;
            else
                error('Folder %s does not exist',inputFolder)
            end
            this.refresh
        end
        function refresh(this,fileName)
            
            pkgStr = 'lsdyna.read.';
            if nargin<2
                % No fileName specified -> refresh all
                allMcls = this.getAsciiDbMetaclasses;
                for a = 1:numel(allMcls)
                    this.refresh(allMcls(a))
                end
                return;
            end
            % We need the fileName (elout, bndout, etc) and the metaclass
            % object (lsdyna.read.elout, lsdyna.read.bndout, etc)
            if ischar(fileName)
                mcls = meta.class.fromName([pkgStr fileName]);
            elseif isa(fileName,'meta.class')
                mcls = fileName;
                fileName = mcls.Name(length(pkgStr)+1:end);
            else
                error('Input must be file name or metaclass')
            end
            
            % Actually try to read this database file
            fcn = str2func(mcls.Name);
            asciiObj = fcn(this.folder);
            
            % Add appropriately named properties
            % TODO: add method to test if asciiObj actually existed
            if isempty(asciiObj)
                % TODO: remove a property if it exists
            else
                if ~isprop(this, fileName)
                    addprop(this,fileName);
                end
                this.(fileName) = asciiObj;
            end
            
        end
    end
    
    methods (Static)
        function allMcls = getAsciiDbMetaclasses
            pkgStr = 'lsdyna.read.';
            % No fileName specified -> refresh all
            allFiles = struct2table(dir(fullfile(fileparts(mfilename('fullpath')),'*.m')));
            allFiles.mcls(:,1) = {[]};
            for a = 1:size(allFiles,1)
                mcls = meta.class.fromName([pkgStr allFiles.name{a}(1:end-2)]);
                if any(strcmp([pkgStr 'DATABASE_FILE'], {mcls.SuperclassList.Name}))
                    allFiles.mcls{a} = mcls;
                end
            end
            allMcls = cat(1,allFiles.mcls{:});
        end
    end

end