# matlab-lsdyna

This project contains a reader of ascii results files from the Finite Element solver LS-DYNA, and a wrapper to run LS-DYNA simulations programmatically from MATLAB. This project is not affiliated in any way with the creators or distributors of LS-DYNA and thus is totally unofficial.

Currently, matlab-lsdyna is written for and tested on a Windows environment. ASCII database reading should by system independent, but code to run simulations is expected to fail on other systems. Efforts to further the tested environments are welcome.  
All code is written in MATLAB by Sven Holcombe.

# Features

## Creating and running simulations
-  *lsdyna.simulation*             - Make/read an LS-Dyna simulation from a folder

## Reading ASCII LS-Dyna output database files
-  *lsdyna.read.asciiFiles*        - Read all available output databases
-  *lsdyna.read.bndout*            - Read boundary conditions output
-  *lsdyna.read.elout*             - Read element data output
-  *lsdyna.read.nodfor*            - Read nodal forces data output
-  *lsdyna.read.nodout*            - Read nodal coord/disp/vel/acc data output
-  *lsdyna.read.rbdout*            - Read rigid body data output





# Example: running simulations

## Basic usage (run one simulation):

```matlab
   S = lsdyna.simulation('C:\FolderToSim\mainFile.k')
   S.run
``` 
 
##  Multiple simulations (in series):
```matlab
   baseFolder = 'C:\FolderToSims';
   for i = 1:10
      simFolder = fullfile(baseFolder,sprintf('sim%d',i));
      S(i) = lsdyna.simulation(fullfile(simFolder,'mainFile.k'));
   end
   S.run % Each simulation will be run, one after the other
``` 
 
##  Multiple simulations (in parallel):
```matlab
   baseFolder = 'C:\FolderToSims';
   for i = 1:10
      simFolder = fullfile(baseFolder,sprintf('sim%d',i));
      S(i) = lsdyna.simulation(fullfile(simFolder,'mainFile.k'));
      S(i).cmdBlocking = false;
   end
   % Run simulations in parallel using 4 threads. The first 4
   % simulations will start in a new command window, and when each is
   % complete, it will fire the next simulation to run in the available
   % thread.
   S.run('threads',4)
```

# Example: reading ASCII database files
```matlab

  out = lsdyna.read.asciiFiles(folder)
 
  out = 
    asciiFiles with properties:
  
      folder: 'C:\Folder\Holding\Simulation'
      rbdout: [1x1 lsdyna.read.rbdout]
      nodfor: [1x1 lsdyna.read.nodfor]
      bndout: [1x1 lsdyna.read.bndout]
      nodout: [1x1 lsdyna.read.nodout]
       elout: [1x1 lsdyna.read.elout]
```

----------------
UNDER DEVELOPMENT
----------------
Some basic (underlying) utilities for extracting parts, nodes, and elements from kFiles has been created. However, for better extensibility these should be wrapped by a clean object-oriented interface.

# Example: reading LS-DYNA k-file
```matlab
kFileStr = 'GHBMC_M50-O_v4-5_20160901.k';
[PART, NODE, ELEMENT_SHELL, ELEMENT_SOLID] = lsdyna.read.kfile(kFileStr);
figure, plot3(NODE.x,NODE.y,NODE.z,'.'), axis image, view(3)
```

