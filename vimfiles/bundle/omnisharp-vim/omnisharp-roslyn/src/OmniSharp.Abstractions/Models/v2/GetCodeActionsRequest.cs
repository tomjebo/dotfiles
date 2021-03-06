using OmniSharp.Mef;

namespace OmniSharp.Models.V2
{
    [OmniSharpEndpoint(OmnisharpEndpoints.V2.GetCodeActions, typeof(GetCodeActionsRequest), typeof(GetCodeActionsResponse))]
    public class GetCodeActionsRequest : Request, ICodeActionRequest
    {
        public Range Selection { get; set; }
    }
}
