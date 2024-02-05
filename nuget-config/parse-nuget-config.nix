{ lib, parseXml }:
{ nugetConfigText }:
with builtins;
with lib.trivial;
let

  findLastIndex = pred: default: list:
    let state =
      foldl' (state: el:
        if pred el then
          { index = state.index + 1; lastFoundIndex = state.index; }
        else
          state // { index = state.index + 1; }
      ) { index = 0; lastFoundIndex = -1; } list;
    in
    if state.lastFoundIndex == -1 then
      default
    else
      state.lastFoundIndex;

  nugetConfigurationXml =
    pipe (parseXml nugetConfigText) [
      (x: assert x.type == "success"; x.value)
      (x: assert x.type == "root"; x.children)
      (lib.findFirst (x: x.name or null == "configuration") null)
    ];
in
{
  # TODO: Add error handling
  packageSources =
    pipe nugetConfigurationXml [
      (x: x.children)
      (lib.findFirst (x: x.name or null == "packageSources") null)
      (x: x.children)
      (filter (x: x.name or null == "add" || x.name or null == "clear"))
      (pkgSrcsXml:
        let 
          lastClearIdx = findLastIndex (x: x.name or null == "clear") null pkgSrcsXml;
        in
        if length pkgSrcsXml != 0 && lastClearIdx == null then

          throw "packageSources must be empty (default) or contain <clear />, because otherwise it is not reliable to resolve package sources"
        else
          lib.drop (lastClearIdx + 1) pkgSrcsXml
      )
      (map (x: {
        name = x.attributes.key;
        value = x.attributes.value;
      }))
      listToAttrs
    ];
  packageSourceMapping =
    pipe nugetConfigurationXml [
      (x: x.children)
      (lib.findFirst (x: x.name or null == "packageSourceMapping") null)
      (x: x.children)
      (filter (x: x.name or null == "packageSource"))
      (map (s: 
        {
          name = s.attributes.key;
          value = {
            patterns =
              pipe s.children [
                (filter (x: x.name or null == "package"))
                (map (x: x.attributes.pattern))
              ];
            };
        }
      ))
      listToAttrs
    ];
}

