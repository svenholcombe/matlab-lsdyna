classdef rbdout < lsdyna.read.DATABASE_FILE
    %RBDOUT Read a rigid body output (rbdout) LS-DYNA ascii file
    %   rbdout = lsdyna.read.rbdout(folder)
    
    properties
        file = 'rbdout'
        RBD_INFO
        RBD_DATA
    end
    methods
        function this = rbdout(varargin)
            this = this@lsdyna.read.DATABASE_FILE(varargin{:});
        end
    end
    methods (Hidden)
        function addDerivedDataChannels(~)
        end
        function parseFileContents(rbdout, inStr)
            %%
            % Find the timestep anchors throughout the file
            sciFloatPattern = rbdout.sciNumRegexpPattern;
            tStepPattern = ['^  r i g i d   b o d y   m o t i o n   a t  cycle=\s*(\d)+\s+time=\s+(' sciFloatPattern ')'];
            [~,~,~,~,te] = regexp(inStr,tStepPattern,'lineanchors');
            te = cat(1,te{:});
            timestepArr = str2num(char(te(:,2))); %#ok<ST2NM>
            nTimesteps = length(timestepArr);
            
            %%
            % First check the string chunk between first two timesteps to get a
            % template for which channels/elements to expect in rest of file
            if isempty(timestepArr)
                return
            end
            %%
            % Search for rigid body info
            [~,rbdEnds,~,~,rbdTxt] = regexp(inStr,'^ (nodal )?rigid body\s*(\d+)','lineanchors');
            rbdTxtPair = cat(1,rbdTxt{:});
            rbdIds = str2num(char(rbdTxtPair(:,2))); %#ok<ST2NM>
            [unqRbdIds, firstRibId] = unique(rbdIds,'stable');
            nRgdBds = length(unqRbdIds);
            
            % Store meta-data about each rigid body found
            rbdout.RBD_INFO = array2table(unqRbdIds,'Var',{'RBD_ID'});
            rbdout.RBD_INFO.isNodalRB = strcmp('nodal ', rbdTxtPair(firstRibId,1));
            
            % Build the string format for ascii text in rbdout file
            fmtCell = {
                ['   coordinates:' repmat(' %f',1,3)]
                [' displacements:' repmat(' %f',1,6)]
                ['    velocities:' repmat(' %f',1,6)]
                [' accelerations:' repmat(' %f',1,6)]
                ' principal or user defined local coordinate direction vectors'
                '     a           b           c'
                ['   row 1' repmat(' %f',1,3)]
                ['   row 2' repmat(' %f',1,3)]
                ['   row 3' repmat(' %f',1,3)]
                ' output in principal or user defined local coordinate directions'
                '     a           b           c    a-rot  b-rot  c-rot'
                [' displacements:' repmat(' %f',1,6)]
                ['    velocities:' repmat(' %f',1,6)]
                [' accelerations:' repmat(' %f',1,6)]
                };
            % We can fetch ALL of these at once for all rigid bodies. Each
            % rigid body's data consists of 48 separate numbers:
            fmtStr = [fmtCell{:}];
            rdbDat = sscanf(inStr(bsxfun(@plus, rbdEnds(:)', (91:1128)')),fmtStr);
            
            % Break into timestep-by-48channels-by-rgdBds array
            rdbDat = permute(reshape(rdbDat, 48,nRgdBds, nTimesteps), [3 1 2]);

            % Extract data
            rbdout.RBD_DATA = array2table(timestepArr ,'Var',{'timestep'});
            % Coordinates, displacements, velocities, accelerations in xyz
            rbdout.RBD_DATA.coord_xyz    = rdbDat(:,1:3,:);
            rbdout.RBD_DATA.disp_xyz     = rdbDat(:,4:6,:);
            rbdout.RBD_DATA.disp_rot_xyz = rdbDat(:,7:9,:);
            rbdout.RBD_DATA.vel_xyz      = rdbDat(:,10:12,:);
            rbdout.RBD_DATA.vel_rot_xyz  = rdbDat(:,13:15,:);
            rbdout.RBD_DATA.acc_xyz      = rdbDat(:,16:18,:);
            rbdout.RBD_DATA.acc_rot_xyz  = rdbDat(:,19:21,:);
            % Direction vectors for local abc rigid body coordinate system
            rbdout.RBD_DATA.abc_dir_vecs = cellfun(@(x)reshape(x,3,3)',...
                permute(num2cell(rdbDat(:,22:30,:), 2), [1 3 2]), 'Un',0);
            % Coordinates, displacements, velocities, accelerations in abc
            rbdout.RBD_DATA.disp_abc     = rdbDat(:,31:33,:);
            rbdout.RBD_DATA.disp_rot_abc = rdbDat(:,34:36,:);
            rbdout.RBD_DATA.vel_abc      = rdbDat(:,37:39,:);
            rbdout.RBD_DATA.vel_rot_abc  = rdbDat(:,40:42,:);
            rbdout.RBD_DATA.acc_abc      = rdbDat(:,43:45,:);
            rbdout.RBD_DATA.acc_rot_abc  = rdbDat(:,46:48,:);
        end
    end
end