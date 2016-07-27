classdef nodout < lsdyna.read.DATABASE_FILE
    %NODOUT Read a rigid body output (nodout) LS-DYNA ascii file
    %   nodout = lsdyna.read.nodout(folder)
    
    properties
        file = 'nodout'
        NODE_INFO
        NODE_DATA
    end
    methods
        function this = nodout(varargin)
            this = this@lsdyna.read.DATABASE_FILE(varargin{:});
        end
    end
    methods (Hidden)
        function addDerivedDataChannels(~)
        end
        function parseFileContents(this, inStr)
            
            %%
            % Find the timestep anchors throughout the file
            sciFloatPattern = this.sciNumRegexpPattern;
            tStepPattern = ['^ n o d a l   p r i n t   o u t   f o r   t i m e  s t e p\s*(\d)+\s+\( at time (' sciFloatPattern ') \)'];
            [timestepInds,timestepEnds,~,~,te] = regexp(inStr,tStepPattern,'lineanchors');
            te = cat(1,te{:});
            timestepArr = str2num(char(te(1:2:end,2))); %#ok<ST2NM>
            nTimesteps = length(timestepArr);
            
            %%
            % First check the string chunk between first two timesteps to get a
            % template for which channels/elements to expect in rest of file
            if isempty(timestepArr)
                return
            elseif isscalar(timestepArr)
                inStrA = inStr(timestepInds(1):end);
            else
                inStrA = inStr(timestepInds(1):timestepInds(2));
            end
            
            %%
            nodeNoStrs = regexp(inStrA,'^\s*\d+','lineanchors','match');
            nodeIDs = sscanf(sprintf('%s ',nodeNoStrs{:}),'%d');
            nNodes = length(nodeIDs);
            this.NODE_INFO = array2table(nodeIDs,'Var',{'NODE_ID'});
            
            % Node position data sits in 12 channels: x-disp y-disp z-disp
            % x-vel y-vel z-vel x-accl y-accl z-accl x-coor y-coor z-coor
            fmtStr = [' %*d' repmat(' %f',1,12)];
            nChPerLine = 2 + 154;
            nodDat = sscanf(inStr(bsxfun(@plus, ...
                reshape(timestepEnds(1:2:end),1,[])+157,...
                (0:nNodes*nChPerLine)')),fmtStr);
            % Get data into time-by-channel-by-nodeNum array
            nodDat = permute(reshape(nodDat, 12, nNodes, nTimesteps), [3 1 2]);
            
            % Assign channels
            this.NODE_DATA = array2table(timestepArr ,'Var',{'timestep'});
            this.NODE_DATA.disp_xyz     = nodDat(:,1:3,:);
            this.NODE_DATA.vel_xyz      = nodDat(:,4:6,:);
            this.NODE_DATA.acc_xyz      = nodDat(:,7:9,:);
            this.NODE_DATA.coord_xyz   = nodDat(:,10:12,:);
            
            % Node rotational data sits in 12 channels
            nChPerLine = 2 + 118;
            fmtStr = [' %*d' repmat(' %f',1,9)];
            nodDat = sscanf(inStr(bsxfun(@plus, ...
                reshape(timestepEnds(2:2:end),1,[])+124,...
                (1:nNodes*nChPerLine)')),fmtStr);
            % Get data into time-by-channel-by-nodeNum array
            nodDat = permute(reshape(nodDat, 9, nNodes, nTimesteps), [3 1 2]);
            
            % Assign rotational channels
            this.NODE_DATA.disp_rot_xyz     = nodDat(:,1:3,:);
            this.NODE_DATA.vel_rot_xyz      = nodDat(:,4:6,:);
            this.NODE_DATA.acc_rot_xyz      = nodDat(:,7:9,:);
        end
    end
end