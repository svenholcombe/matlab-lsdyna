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
            
            % Grab and concatenate each card's active strings
            strs = cat(1,C.ActiveString);
            strsLineCounts = cellfun(@numel,{C.ActiveString});
            
            % Turn comma-sep lines into spaced lines and read the data
            strs = C.convertCommaSepStrsToSpacedStrs(strs,FLDS.size);
            NODEDATA = C.convertSpacedStrsToMatrix(strs,FLDS);
            
            % Convert appropriate data field types
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