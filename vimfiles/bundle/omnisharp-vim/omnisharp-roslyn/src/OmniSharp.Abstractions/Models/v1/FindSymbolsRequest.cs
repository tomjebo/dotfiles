using OmniSharp.Mef;

namespace OmniSharp.Models
{
    [OmniSharpEndpoint(OmnisharpEndpoints.FindSymbols, typeof(FindSymbolsRequest), typeof(QuickFixResponse))]
    public class FindSymbolsRequest : IRequest
    {
        public string Language { get; set; }
        public string Filter { get; set; }
    }
}
