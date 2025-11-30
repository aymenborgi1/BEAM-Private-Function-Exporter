-module(expt_patcher).
-export([patch/1]).

patch(BeamFile) ->
    {ok, Binary} = file:read_file(BeamFile),

    % Get all private functions and their info
    {ok, {_Module, Chunks}} = beam_lib:chunks(BeamFile, [exports, locals, atoms]),
    {locals, Locals} = lists:keyfind(locals, 1, Chunks),
    {atoms, Atoms} = lists:keyfind(atoms, 1, Chunks),

    % Get function labels from disassembly
    {beam_file, _, _, _, _, Functions} = beam_disasm:file(BeamFile),
    FunctionLabels = [{Name, Arity, Label} || {function, Name, Arity, Label, _} <- Functions],

    % Filter out module_info and get all private functions with their data
    PrivateFunctions = [{F, A} || {F, A} <- Locals, F =/= module_info],

    io:format("Found ~p private functions: ~p~n", [length(PrivateFunctions), PrivateFunctions]),

    % Build new export entries for all private functions
    NewExportEntries = [build_export_entry(F, A, Atoms, FunctionLabels) || {F, A} <- PrivateFunctions],

    % Patch the BEAM binary
    PatchedBinary = patch_expt_multi(Binary, NewExportEntries),

    OutputFile = filename:rootname(BeamFile) ++ "_expt_patched.beam",
    file:write_file(OutputFile, PatchedBinary),
    io:format("SUCCESS: Added ~p private functions to exports~n", [length(PrivateFunctions)]),
    {ok, OutputFile}.

build_export_entry(FuncName, Arity, Atoms, FunctionLabels) ->
    AtomIndex = find_atom_index(FuncName, Atoms),
    Label = find_function_label(FuncName, Arity, FunctionLabels),
    {AtomIndex, Arity, Label}.

find_atom_index(Atom, Atoms) ->
    case lists:keyfind(Atom, 2, Atoms) of
        {Index, Atom} -> Index;
        false -> 0
    end.

find_function_label(Name, Arity, FunctionLabels) ->
    case lists:keyfind({Name, Arity}, 1, [{{N, A}, L} || {N, A, L} <- FunctionLabels]) of
        {{Name, Arity}, Label} -> Label;
        false -> 0
    end.

patch_expt_multi(Binary, NewExportEntries) ->
    % Parse FOR1 header
    <<"FOR1", _OrigFor1Size:32/big, "BEAM", Rest/binary>> = Binary,

    % Find and patch ExpT chunk
    {ExptPos, _} = binary:match(Rest, <<"ExpT">>),
    <<BeforeExpt:ExptPos/binary, "ExpT", Size:32/big, Data:Size/binary, AfterExpt/binary>> = Rest,

    % Parse current ExpT data
    <<Count:32/big, ExportEntries/binary>> = Data,

    % Add all new export entries
    NewEntries = << <<AtomIdx:32/big, Arity:32/big, Label:32/big>> || {AtomIdx, Arity, Label} <- NewExportEntries >>,
    NewExportEntries_Binary = <<ExportEntries/binary, NewEntries/binary>>,
    NewCount = Count + length(NewExportEntries),
    NewData = <<NewCount:32/big, NewExportEntries_Binary/binary>>,
    NewSize = byte_size(NewData),

    % Handle padding
    OldPadding = case Size rem 4 of 0 -> 0; P -> 4-P end,
    <<_:OldPadding/binary, AfterPadding/binary>> = AfterExpt,
    NewPadding = case NewSize rem 4 of 0 -> <<>>; Q -> binary:copy(<<0>>, 4-Q) end,

    % Rebuild the BEAM content
    NewRest = <<BeforeExpt/binary, "ExpT", NewSize:32/big, NewData/binary, NewPadding/binary, AfterPadding/binary>>,
    NewFor1Size = byte_size(NewRest) + 4,  % +4 for "BEAM"

    % Rebuild complete BEAM file
    <<"FOR1", NewFor1Size:32/big, "BEAM", NewRest/binary>>.
