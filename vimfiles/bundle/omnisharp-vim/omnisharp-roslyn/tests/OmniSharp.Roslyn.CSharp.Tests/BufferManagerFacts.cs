using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using OmniSharp.Models;
using OmniSharp.Services;
using Xunit;

namespace OmniSharp.Tests
{
    public class BufferManagerFacts
    {
        [Fact]
        public async Task UpdateBufferIgnoresVoidRequests()
        {
            var workspace = await TestHelpers.CreateSimpleWorkspace("class C {}", "test.cs");
            Assert.Equal(2, workspace.CurrentSolution.Projects.Count());
            Assert.Equal(1, workspace.CurrentSolution.Projects.ElementAt(0).Documents.Count());
            Assert.Equal(1, workspace.CurrentSolution.Projects.ElementAt(1).Documents.Count());

            await workspace.BufferManager.UpdateBuffer(new Request() { });
            Assert.Equal(2, workspace.CurrentSolution.Projects.Count());
            Assert.Equal(1, workspace.CurrentSolution.Projects.ElementAt(0).Documents.Count());
            Assert.Equal(1, workspace.CurrentSolution.Projects.ElementAt(1).Documents.Count());

            await workspace.BufferManager.UpdateBuffer(new Request() { FileName = "", Buffer = "enum E {}" });
            Assert.Equal(2, workspace.CurrentSolution.Projects.Count());
            Assert.Equal(1, workspace.CurrentSolution.Projects.ElementAt(0).Documents.Count());
            Assert.Equal(1, workspace.CurrentSolution.Projects.ElementAt(1).Documents.Count());
        }

        [Fact]
        public async Task UpdateBufferIgnoresFilePathsThatDontMatchAProjectPath()
        {
            var workspace = await GetWorkspaceWithProjects();

            await workspace.BufferManager.UpdateBuffer(new Request() { FileName = Path.Combine("some", " path.cs"), Buffer = "enum E {}" });
            var documents = workspace.GetDocuments(Path.Combine("some", "path.cs"));
            Assert.Equal(0, documents.Count());
        }

        [Fact]
        public async Task UpdateBufferFindsProjectBasedOnPath()
        {
            var workspace = await GetWorkspaceWithProjects();

            await workspace.BufferManager.UpdateBuffer(new Request() { FileName = Path.Combine("src", "newFile.cs"), Buffer = "enum E {}" });
            var documents = workspace.GetDocuments(Path.Combine("src", "newFile.cs"));
            Assert.Equal(2, documents.Count());

            foreach (var document in documents)
            {
                Assert.Equal(Path.Combine("src", "project.json"), document.Project.FilePath);
            }
        }

        [Fact]
        public async Task UpdateBufferReadsFromDisk()
        {
            var code = "public class MyClass {}";
            string fileName = Path.GetTempPath() + Guid.NewGuid().ToString() + ".cs";
            var workspace = await TestHelpers.CreateSimpleWorkspace("", fileName);

            File.WriteAllText(fileName, code);
            await workspace.BufferManager.UpdateBuffer(new UpdateBufferRequest { FileName = fileName, FromDisk = true });

            var document = workspace.GetDocument(fileName);
            var text = await document.GetTextAsync();

            Assert.Equal(code, text.ToString());
        }

        [Fact]
        public async Task UpdateBufferFindsProjectBasedOnNearestPath()
        {
            var workspace = new OmnisharpWorkspace(
                new HostServicesAggregator(
                    Enumerable.Empty<IHostServicesProvider>()));

            await TestHelpers.AddProjectToWorkspace(workspace, Path.Combine("src", "root", "foo.csproj"),
                new[] { "" },
                new Dictionary<string, string>() { { Path.Combine("src", "root", "foo.cs"), "class C1 {}" } });

            await TestHelpers.AddProjectToWorkspace(workspace, Path.Combine("src", "root", "foo", "bar", "insane.csproj"),
                new[] { "" },
                new Dictionary<string, string>() { { Path.Combine("src", "root", "foo", "bar", "nested", "code.cs"), "class C2 {}" } });

            await workspace.BufferManager.UpdateBuffer(new Request() { FileName = Path.Combine("src", "root", "bar.cs"), Buffer = "enum E {}" });
            var documents = workspace.GetDocuments(Path.Combine("src", "root", "bar.cs"));
            Assert.Equal(1, documents.Count());
            Assert.Equal(Path.Combine("src", "root", "foo.csproj"), documents.ElementAt(0).Project.FilePath);
            Assert.Equal(2, documents.ElementAt(0).Project.Documents.Count());

            await workspace.BufferManager.UpdateBuffer(new Request() { FileName = Path.Combine("src", "root", "foo", "bar", "nested", "paths", "dance.cs"), Buffer = "enum E {}" });
            documents = workspace.GetDocuments(Path.Combine("src", "root", "foo", "bar", "nested", "paths", "dance.cs"));
            Assert.Equal(1, documents.Count());
            Assert.Equal(Path.Combine("src", "root", "foo", "bar", "insane.csproj"), documents.ElementAt(0).Project.FilePath);
            Assert.Equal(2, documents.ElementAt(0).Project.Documents.Count());
        }

        [Fact]
        public async Task UpdateRequestHandleChanges()
        {

            var workspace = await GetWorkspaceWithProjects();

            await workspace.BufferManager.UpdateBuffer(new Request()
            {
                FileName = Path.Combine("src", "a.cs"),
                Changes = new LinePositionSpanTextChange[]
                {
                    // class C {} -> interface C {}
                    new LinePositionSpanTextChange() {
                        StartLine = 0,
                        StartColumn = 0,
                        EndLine = 0,
                        EndColumn = 5,
                        NewText = "interface"
                    },
                    // interface C {} -> interface I {}
                    // note: this change is relative to the previous
                    // change having been applied
                    new LinePositionSpanTextChange() {
                        StartLine = 0,
                        StartColumn = 10,
                        EndLine = 0,
                        EndColumn = 11,
                        NewText = "I"
                    }
                }
            });

            var document = workspace.GetDocument(Path.Combine("src", "a.cs"));
            Assert.Equal("interface I {}", (await document.GetTextAsync()).ToString());
        }

        private async static Task<OmnisharpWorkspace> GetWorkspaceWithProjects()
        {
            var workspace = new OmnisharpWorkspace(
                new HostServicesAggregator(
                    Enumerable.Empty<IHostServicesProvider>()));

            await TestHelpers.AddProjectToWorkspace(workspace, Path.Combine("src", "project.json"),
                new[] { "dnx451", "dnxcore50" },
                new Dictionary<string, string>() { { Path.Combine("src", "a.cs"), "class C {}" } });

            await TestHelpers.AddProjectToWorkspace(workspace, Path.Combine("test", "project.json"),
                new[] { "dnx451", "dnxcore50" },
                new Dictionary<string, string>() { { Path.Combine("test", "b.cs"), "class C {}" } });

            Assert.Equal(4, workspace.CurrentSolution.Projects.Count());
            foreach (var project in workspace.CurrentSolution.Projects)
            {
                Assert.Equal(1, project.Documents.Count());
            }

            return workspace;
        }
    }
}
