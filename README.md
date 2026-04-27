# dotfiles 
>[!NOTE]
>Looks like we can probably use the MS-ODRAWXML and MS-PPTX ABNFs to gather the list of monikers for CT_TextCharRangeMonikerList.   See [References](#references)

So far, I have: 

```xml
<ac:txMk/> [^1]
<ac:spMk/>
<ac:txMk/>
<ac:spMk/>
<pc:sldLayoutMk/> [^2]
<pc:sldMk/>
<pc:docMk/>
<pc:sldMasterMk/>
```
<details>
<a id="references"></a>
# My heading references

[^1]: The pc prefix is `http://schemas.microsoft.com/office/powerpoint/2013/main/command`

[^2]: ~~Of course~~ ac is `http://schemas.microsoft.com/office/drawing/2013/main/command`

- [x]
- [ ]
</details>
