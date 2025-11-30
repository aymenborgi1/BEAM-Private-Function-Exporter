# BEAM-Private-Function-Exporter
This repository contains an Erlang module (expt_patcher.erl) that rewrites BEAM files by modifying the ExpT (Export Table) chunk, adding private functions so they become callable from outside the module.
This tool is intended for reverse engineering, debugging, instrumentation, and security research where private functions cannot normally be accessed.

## Features

- Extracts private (local) functions from BEAM metadata
    
- Retrieves atom indices and function labels through disassembly
    
- Generates valid export entries for private functions
    
- Patches the BEAM ExpT chunk with correct padding and alignment
    
- Produces a BEAM file where private functions become public
    
- Does not modify bytecode, only metadata

## Repository Files

expt_patcher.erl - Erlang module that patches BEAM files  
README.md - Documentation

## How It Works

1. Read the BEAM file  
    The patcher loads the file as binary data.
    
2. Extract metadata (exports, locals, atoms)  
    It uses beam_lib:chunks/2 to extract:
    

- exports: public functions
    
- locals: private functions
    
- atoms: atom table (names used in the module)
    

3. Disassemble BEAM to retrieve function labels  
    Function labels represent the bytecode entrypoints.
    
4. Build new export entries  
    Each entry contains:
    

- Atom index
    
- Arity
    
- Label (bytecode offset)
    

5. Locate the ExpT chunk  
    The ExpT chunk format is:  
    "ExpT" + Size + Data
    
6. Append new export entries  
    The patcher:
    

- increases the export count
    
- appends new entries
    
- rebuilds the chunk with proper size
    
- ensures correct 4-byte alignment

7. Rebuild the entire BEAM file  
    The patcher reconstructs the chunk list, updates the FOR1 header size, and produces a valid BEAM file.

## Usage

1. Compile the patcher
    

erlc expt_patcher.erl

2. Run the patcher
    

erl -noshell -eval "expt_patcher:patch('file.beam'), halt()."

This generates:  
file_multi_patched.beam

3. Replace the original BEAM file manually
    

mv file.beam file_backup.beam  
mv file_multi_patched.beam file.beam
