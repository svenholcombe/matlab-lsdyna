classdef NODE < lsdyna.keyword.card
    %lsdyna.keyword.NODE
    
    properties (Constant)
        KeywordMatch = "NODE";
        LineDefinitions = lsdyna.keyword.utils.cardLineDefinition("NODE");
    end
    properties (Constant, Hidden)
        DependentCards = strings(1,0)
    end
    
    properties
        NodeData = table;
    end
    
    methods
        function strs = sca_dataToString(C)
            FLDS = C.LineDefinitions.FLDS{1};
            DATA = table2cell(C.NodeData)';
            
            printSpec = strjoin("%" + FLDS.size + FLDS.fmt,"") + newline;
            strs = splitlines(sprintf(printSpec, DATA{:}));
            strs = strs(1:end-1);
        end
    end
    
    %% CONSTRUCTOR
    methods
        function newCard = NODE(basicCard)
            % Allow empty constructor
            if ~nargin
                return;
            end
            % Elseif isa basicCard then convert
            newCard = basicCard.assignPropsToSubclass(newCard);
            % Else call superclass constructor on varargin
        end
        
        function C = arr_stringToData(C)
            % Parse the string data and populate this card's numeric data
            lineDefns = C(1).LineDefinitions;
            % There's only 1 repeated line for NODE cards. Just use it.
            FLDS = lineDefns.FLDS{1};
            nFlds = size(FLDS,1);
            fmtStr = cell2mat(strcat('%', arrayfun(@num2str,FLDS.size,'Un',0), FLDS.fmt)');
            
            % Grab and concatenate each card's active strings
            strs = cat(1,C.ActiveString);
            strsLineCounts = cellfun(@numel,{C.ActiveString});
            strs = C.convertCommaSepStrsToSpacedStrs(strs,FLDS.size);
            
            % Convert strings to char matrix, truncate whitespace from long
            % lines and fill mat to expected size with spaces and a newline
            strsAsCharMat = char(strs);
            strsAsCharMat(:,FLDS.endChar(end)+2:end) = [];
            strsAsCharMat(:,FLDS.endChar(end)+1) = newline;
            
            % Default empty pieces to "0" for proper use in sscanf
            for i = 1:nFlds
                emptyMask = all(strsAsCharMat(:,FLDS.charInds{i}) == ' ',2);
                strsAsCharMat(emptyMask,FLDS.endChar(i)) = '0';
            end
            
            % Scanf the string and extract numeric data
            NODEDATA = reshape(sscanf(strsAsCharMat',[fmtStr newline]), nFlds,[])';
            NODE = array2table(NODEDATA,'Var',FLDS.fld);
            NODE.nid = uint32(NODE.nid);
            NODE.tc = uint8(NODE.tc);
            NODE.rc = uint8(NODE.rc);
            
            % Identify rows belonging to each individual card
            linesEndAt = cumsum(strsLineCounts);
            linesStartAt = [1 linesEndAt(1:end-1)+1];
            NODEset = arrayfun(@(from,to)NODE(from:to,:),linesStartAt,linesEndAt,'Un',0);
            [C.NodeData] = NODEset{:};
        end
    end
end