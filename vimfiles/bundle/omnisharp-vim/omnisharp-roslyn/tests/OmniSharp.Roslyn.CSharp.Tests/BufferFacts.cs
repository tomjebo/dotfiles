using System.Linq;
using System.Threading.Tasks;
using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.Text;
using OmniSharp.Roslyn.CSharp.Services.Buffer;
using OmniSharp.Services;
using Xunit;

namespace OmniSharp.Roslyn.CSharp.Tests
{
    public class BufferFacts
    {
        private void CreateSimpleWorkspace(out OmnisharpWorkspace workspace, out ChangeBufferService controller, out DocumentInfo document, string filename, string contents)
        {
            workspace = new OmnisharpWorkspace(
                new HostServicesAggregator(
                    Enumerable.Empty<IHostServicesProvider>()));

            controller = new ChangeBufferService(workspace);

            var projectInfo = ProjectInfo.Create(ProjectId.CreateNewId(), VersionStamp.Create(),
                "ProjectNameVal", "AssemblyNameVal", LanguageNames.CSharp);

            document = DocumentInfo.Create(DocumentId.CreateNewId(projectInfo.Id), filename,
                null, SourceCodeKind.Regular,
                TextLoader.From(TextAndVersion.Create(SourceText.From(contents), VersionStamp.Create())),
                filename);

            workspace.AddProject(projectInfo);
            workspace.AddDocument(document);
        }

        [Fact]
        public async Task ChangeBuffer_InsertRemoveChanges()
        {
            OmnisharpWorkspace workspace;
            ChangeBufferService controller;
            DocumentInfo document;
            CreateSimpleWorkspace(out workspace, out controller, out document, "test.cs", "class C {}");

            // insert edit
            await controller.Handle(new OmniSharp.Models.ChangeBufferRequest()
            {
                StartLine = 0,
                StartColumn = 0,
                EndLine = 0,
                EndColumn = 0,
                NewText = "farboo",
                FileName = "test.cs"
            });
            var sourceText = await workspace.CurrentSolution.GetDocument(document.Id).GetTextAsync();
            Assert.Equal("farbooclass C {}", sourceText.ToString());

            // remove edit
            await controller.Handle(new OmniSharp.Models.ChangeBufferRequest()
            {
                StartLine = 0,
                StartColumn = 0,
                EndLine = 0,
                EndColumn = 6,
                NewText = "",
                FileName = "test.cs"
            });
            sourceText = await workspace.CurrentSolution.GetDocument(document.Id).GetTextAsync();
            Assert.Equal("class C {}", sourceText.ToString());

            // modification edit
            await controller.Handle(new OmniSharp.Models.ChangeBufferRequest()
            {
                StartLine = 0,
                StartColumn = 0,
                EndLine = 0,
                EndColumn = 5,
                NewText = "interface",
                FileName = "test.cs"
            });
            sourceText = await workspace.CurrentSolution.GetDocument(document.Id).GetTextAsync();
            Assert.Equal("interface C {}", sourceText.ToString());
        }
    }
}
