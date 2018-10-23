classdef NODE < lsdyna.keyword.card
    %lsdyna.keyword.NODE
    
    properties (Constant)
        KeywordMatch = "NODE";
    end
    properties (Constant, Hidden)
        DependentCards = strings(1,0)
    end
    
    properties
        NodeData = table;
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
        
        function C = parseData(C)
            % Parse the string data and populate this card's numeric data
            
            FLDS = cell2table({
                'nid' 'x'  'y'  'z' 'tc' 'rc'
                8      16   16   16    8   8
                "d"   "f"  "f"  "f"  "f"  "f"
                }','Var',{'fld','size','fmt'});
            FLDS.startChar = 1+[0;cumsum(FLDS.size(1:end-1))];
            FLDS.endChar = FLDS.startChar + FLDS.size - 1;
            FLDS.charInds = arrayfun(@(from,to)from:to,FLDS.startChar,FLDS.endChar,'Un',0);
            nFlds = size(FLDS,1);
            fmtStr = cell2mat(strcat('%', arrayfun(@num2str,FLDS.size,'Un',0), FLDS.fmt)');
            
            strs = cat(1,C.ActiveString);
            strsLineCounts = cellfun(@numel,{C.ActiveString});
            strs = C.convertCommaSepStrsToSpacedStrs(strs,FLDS.size);

            
            %%
            
            strsAsCharMat = char(strs);
            strsAsCharMat(1,size(strsAsCharMat,2)+1:FLDS.endChar(end)) = ' ';
            sizeBasedText = strsAsCharMat(:,1:FLDS.endChar(end))';
            sizeBasedText(end+1:max(FLDS.endChar),:) = ' ';
            
            for i = 1:nFlds
                emptyMask = all(sizeBasedText(FLDS.charInds{i},:) == ' ',1);
                sizeBasedText(FLDS.endChar(i),emptyMask) = '0';
            end
            NODEDATA = reshape(sscanf(sizeBasedText,fmtStr), nFlds,[])';
            NODE = array2table(NODEDATA,'Var',FLDS.fld);
            NODE.nid = uint32(NODE.nid);
            NODE.tc = uint8(NODE.tc);
            NODE.rc = uint8(NODE.rc);
            %%
            
            linesEndAt = cumsum(strsLineCounts);
            linesStartAt = [1 linesEndAt(1:end-1)+1];
            
            NODEset = arrayfun(@(from,to)NODE(from:to,:),linesStartAt,linesEndAt,'Un',0);
            [C.NodeData] = NODEset{:};
            
        end
    end
end