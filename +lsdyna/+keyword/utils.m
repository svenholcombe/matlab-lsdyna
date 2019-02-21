classdef utils
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    
    methods (Static = true)
        function defns = cardLineDefinition(cardId)
            switch upper(cardId)
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
                    % Note: there are old and new formats for the
                    % ELEMENT_SOLID layout. One has the 8-node in 1 line
                    % card definition but there is also a 10-node in 2
                    % lines cards definition. It will be the responsibility
                    % of the ELEMENT_SOLID.arr_stringToData() function to
                    % determine which is appropriate.
                    FLDSsolid = cell2table({
                        'eid' 'pid' 'n1' 'n2' 'n3' 'n4' 'n5' 'n6' 'n7' 'n8'
                        8         8    8    8    8    8    8    8    8    8
                        "d"     "d"  "d"  "d"  "d"  "d"  "d"  "d"  "d"  "d"
                        }','Var',{'fld','size','fmt'});
                    FLDSsolid10_line1 = cell2table({
                        'eid' 'pid'
                        8         8
                        "d"     "d"
                        }','Var',{'fld','size','fmt'});
                    FLDSsolid10_line2 = cell2table({
                        'n1' 'n2' 'n3' 'n4' 'n5' 'n6' 'n7' 'n8' 'n9' 'n10'
                        8      8    8    8    8    8    8    8    8    8
                        "d"   "d"  "d"  "d"  "d"  "d"  "d"  "d"  "d"  "d"
                        }','Var',{'fld','size','fmt'});
                    defns = cell2table({
                        "ELEMENT_SOLID"                     1 @(i)true(size(i)) FLDSsolid
                        "ELEMENT_SOLID (ten nodes format)"  1 @(i)mod(i,2)==1   FLDSsolid10_line1
                        "ELEMENT_SOLID (ten nodes format)"  2 @(i)mod(i,2)==0   FLDSsolid10_line2
                        }, 'Var', {'keyword','lineNo','lineMatchFcn','FLDS'});
                case "ELEMENT_DISCRETE"
                    FLDS = cell2table({
                        'eid' 'pid' 'n1' 'n2' 'vid' 's' 'pf' 'offset'
                        8      8     8    8    8    16   8    16
                        "d"   "d"   "d"  "d"  "d"  "f"  "d"   "f"
                        }','Var',{'fld','size','fmt'});
                    defns = cell2table({
                        "ELEMENT_DISCRETE" 1 @(i)true(size(i)) FLDS
                        }, 'Var', {'keyword','lineNo','lineMatchFcn','FLDS'});
                case "ELEMENT_BEAM"
                    FLDS = cell2table({
                        'eid' 'pid' 'n1' 'n2' 'n3' 'rt1' 'rr1' 'rt2' 'rr2' 'local'
                        8      8     8    8    8    8     8     8     8     8
                        "d"   "d"   "d"  "d"  "d"  "d"  "d"   "d"    "d"   "d"
                        }','Var',{'fld','size','fmt'});
                    defns = cell2table({
                        "ELEMENT_BEAM" 1 @(i)true(size(i)) FLDS
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

