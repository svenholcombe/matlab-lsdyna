classdef nodfor < lsdyna.read.DATABASE_FILE
    %NODFOR Read a nodal forces output (nodfor) LS-DYNA ascii file
    %   nodfor = lsdyna.read.nodfor(folder)
    
    properties
        file = 'nodfor'
        NODE_INFO
        NODE_DATA
    end
    methods
        function this = nodfor(varargin)
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
            
            % Get all instances of "var= value" throughout file
            [a,~,~,~,e] = regexp(inStr,['(\w+)=\s+('  sciFloatPattern ')']);
            e = cat(1,e{:});
            % Extract the time sequence, given only once per timestep
            tmask = strcmp('t',e(:,1));
            etVals = str2num(char(e(:,2))); %#ok<ST2NM>
            eVals = etVals(~tmask);
            tVals = etVals(tmask);
            tNos = cumsum(tmask);
            tNos = tNos(~tmask);
            eLabs = e(~tmask,1);
            [unqLabs, ~, eLabGrp] = unique(eLabs,'stable');
            
            nTimesteps = nnz(tmask);
            nVars = length(unqLabs);
            nNodes = length(eVals) / nTimesteps / nVars;
            nodeNos = reshape(repmat(1:nNodes, nVars, nTimesteps),[],1);
            dataMat = zeros(nTimesteps, nVars, nNodes);
            
            dataMat(sub2ind(size(dataMat), tNos, eLabGrp, nodeNos)) = eVals;
            
            % Get the nodeId (nd#  12345) strings giving N nodes
            [~,~,~,~,nodNoStrs] = regexp(inStr(a(1):a(nVars*nNodes)),'nd#\s+(\d+)');
            nodeIds = cellfun(@str2double,cat(2,nodNoStrs{:}));
            
            this.NODE_INFO = array2table(nodeIds(:),'Var',{'NODE_ID'});
            this.NODE_DATA = array2table(tVals,'Var',{'timestep'});
            for vn = 1:length(unqLabs)
                this.NODE_DATA.(unqLabs{vn}) = permute(dataMat(:,vn,:),[1 3 2]);
            end
        end
    end
end