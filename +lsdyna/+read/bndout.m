classdef bndout < lsdyna.read.DATABASE_FILE
    %BNDOUT Read a boundary output (bndout) LS-DYNA ascii file
    %   bndout = lsdyna.read.rbdout(bndout)
    
    properties
        file = 'bndout'
        BND_INFO
        BND_DATA
    end
    methods
        function this = bndout(varargin)
            this = this@lsdyna.read.DATABASE_FILE(varargin{:});
        end
    end
    methods (Hidden)
        
        function addDerivedDataChannels(~)
        end
        function parseFileContents(this, inStr)
            
            %%
            % Regular expression matching any (optionally) scientific notation number
            sciFloatPattern = '[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?';
            % Find the header (timing) lines
            tStepPattern = ['^ n o d a l   f o r c e/e n e r g y    o u t p u t  t=\s*(' sciFloatPattern ')'];
            [~,~,~,~,te] = regexp(inStr,tStepPattern,'lineanchors');
            te = cat(1,te{:});
            timestepArr = str2num(char(te)); %#ok<ST2NM>
            nTimesteps = length(timestepArr);
            
            if ~nTimesteps
                return
            end
            %%
            [~,matStrEnds,~,~,matNosTxt] = regexp(inStr,'^mat#\s*(\d+)','lineanchors');
            matTxt = cat(1,matNosTxt{:});
            matIds = str2num(char(matTxt)); %#ok<ST2NM>
            [unqMatIds, firstMatId] = unique(matIds);
            
            % bndout stores some xyz components - let's combine them
            triplets = cell2table({
                'force',  [11:23 33:45 55:67]
                'moment', [11:23 33:45 55:67]+122
                'total',  [11:23 33:45 55:67]+122+81
                },'Var',{'fld','strInds'});
            
            inStrInds = bsxfun(@plus, triplets.strInds, reshape(matStrEnds,1,1,[]));
            % Get values for force, moment, total in
            % timestep-by-xyz-by-mat-by-fmt array
            tripletVals = permute(reshape(str2num(inStr(inStrInds(:,:))),...
                size(inStrInds,1),3,[], nTimesteps), [4 2 3 1]); %#ok<ST2NM>

            this.BND_DATA = array2table(timestepArr,'Var',{'timestep'});
            for i = 1:size(triplets,1)
                this.BND_DATA.([triplets.fld{i} '_xyz']) = tripletVals(:,:,:,i);
            end
            % Append the energy output by force and total
            this.BND_DATA.energy = reshape(str2num(inStr(...
                bsxfun(@plus,matStrEnds(:), 78:90)))',[],nTimesteps)'; %#ok<ST2NM>
            this.BND_DATA.etotal = reshape(str2num(inStr(...
                bsxfun(@plus,matStrEnds(:), (78:90)+203)))',[],nTimesteps)'; %#ok<ST2NM>
            % Append mat numbers and the set they belong to
            this.BND_INFO = array2table(unqMatIds(:), 'Var',{'MAT_ID'});
            this.BND_INFO.SET_ID = str2num(inStr(bsxfun(@plus,matStrEnds(firstMatId)', 101:113))); %#ok<ST2NM>
        end
    end
end