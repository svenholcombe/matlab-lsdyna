classdef utils
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    methods (Static)
        function defns = cardLineDefinition(cardId)
            switch cardId
                case "NODE"
                    FLDS = cell2table({
                        'nid' 'x'  'y'  'z' 'tc' 'rc'
                        8      16   16   16    8   8
                        "d"   "f"  "f"  "f"  "f"  "f"
                        }','Var',{'fld','size','fmt'});
                    % Note: this is for the 8-node in 1 card definition.
                    % There is also a 10-node in 2 cards definition not yet
                    % implemented.
                    defns = cell2table({
                        "NODE" 1 @(i)true(size(i)) FLDS
                        }, 'Var', {'keyword','lineNo','lineMatchFcn','FLDS'});
                case "ELEMENT_SHELL"
                    FLDSshell = cell2table({
                        'eid' 'pid' 'n1' 'n2' 'n3' 'n4' 'n5' 'n6' 'n7' 'n8'
                        8         8    8    8    8    8    8    8    8    8
                        "d"     "d"  "d"  "d"  "d"  "d"  "d"  "d"  "d"  "d"
                        }','Var',{'fld','size','fmt'});
                    FLDSshellThick = cell2table({
                        't1' 't2' 't3' 't4' 'beta'
                        16   16   16   16     16
                        "f"  "f"  "f"  "f"    "f"
                        }','Var',{'fld','size','fmt'});
                    defns = cell2table({
                        "ELEMENT_SHELL"             1 @(i)true(size(i)) FLDSshell
                        "ELEMENT_SHELL_THICKNESS"   1 @(i)mod(i,2)==1   FLDSshell
                        "ELEMENT_SHELL_THICKNESS"   2 @(i)mod(i,2)==0   FLDSshellThick
                        }, 'Var', {'keyword','lineNo','lineMatchFcn','FLDS'});
                case "ELEMENT_SOLID"
                    FLDSsolid = cell2table({
                        'eid' 'pid' 'n1' 'n2' 'n3' 'n4' 'n5' 'n6' 'n7' 'n8'
                        8         8    8    8    8    8    8    8    8    8
                        "d"     "d"  "d"  "d"  "d"  "d"  "d"  "d"  "d"  "d"
                        }','Var',{'fld','size','fmt'});
                    % Note: this is for the 8-node in 1 card definition.
                    % There is also a 10-node in 2 cards definition not yet
                    % implemented.
                    defns = cell2table({
                        "ELEMENT_SOLID"             1 @(i)true(size(i)) FLDSsolid
                        }, 'Var', {'keyword','lineNo','lineMatchFcn','FLDS'});
            end
            
            % Push some helpful variables into the FLDS table
            for mNo = 1:size(defns,1)
                FLDS = defns.FLDS{mNo};
                FLDS.startChar = 1+[0;cumsum(FLDS.size(1:end-1))];
                FLDS.endChar = FLDS.startChar + FLDS.size - 1;
                FLDS.charInds = arrayfun(@(from,to)...
                    from:to,FLDS.startChar,FLDS.endChar,'Un',0);
                defns.FLDS{mNo} = FLDS;
            end
        end
    end
end

