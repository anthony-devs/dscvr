export function Pinda() {
  return (
    <section id="pinda" className="py-24 md:py-32">
      <div className="max-w-6xl mx-auto px-6">
        <div className="grid md:grid-cols-2 gap-12 md:gap-20 items-center">
          {/* Left: Chat simulation */}
          <div className="order-2 md:order-1">
            <div className="bg-white rounded-2xl border border-border shadow-xl shadow-foreground/5 overflow-hidden max-w-md mx-auto md:mx-0">
              {/* Chat header */}
              <div className="px-5 py-4 border-b border-border flex items-center gap-3">
                <div className="w-8 h-8 bg-purple-100 rounded-lg flex items-center justify-center">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#8B5CF6" strokeWidth="2"><path d="M12 2a7 7 0 0 1 7 7c0 3-2 5-3.5 6.5L12 19l-3.5-3.5C7 14 5 12 5 9a7 7 0 0 1 7-7z" /></svg>
                </div>
                <div>
                  <p className="text-sm font-semibold">Pinda</p>
                  <p className="text-[10px] text-muted">Reading your library</p>
                </div>
                <span className="ml-auto text-[10px] px-2 py-0.5 bg-amber-100 text-amber-700 rounded-full font-medium">Coming Soon</span>
              </div>

              {/* Messages */}
              <div className="p-5 space-y-4">
                {/* User message */}
                <div className="flex justify-end">
                  <div className="bg-foreground text-background px-4 py-2.5 rounded-2xl rounded-br-md text-sm max-w-[80%]">
                    What are the main findings on attention mechanisms in the papers I saved?
                  </div>
                </div>

                {/* Pinda response */}
                <div className="flex justify-start">
                  <div className="bg-gray-100 px-4 py-3 rounded-2xl rounded-bl-md text-sm max-w-[85%] space-y-2">
                    <p>Based on 4 papers in your library, here are the key findings:</p>
                    <p className="text-muted text-xs">
                      <span className="font-medium text-foreground">1.</span> Self-attention scales quadratically with sequence length (Vaswani et al.)
                    </p>
                    <p className="text-muted text-xs">
                      <span className="font-medium text-foreground">2.</span> Flash Attention reduces memory from O(N&sup2;) to O(N) through tiling...
                    </p>
                    <div className="flex items-center gap-1.5 pt-1">
                      <div className="w-1 h-1 bg-purple-400 rounded-full animate-pulse" />
                      <div className="w-1 h-1 bg-purple-400 rounded-full animate-pulse" style={{ animationDelay: '0.2s' }} />
                      <div className="w-1 h-1 bg-purple-400 rounded-full animate-pulse" style={{ animationDelay: '0.4s' }} />
                    </div>
                  </div>
                </div>
              </div>

              {/* Input bar */}
              <div className="px-4 pb-4">
                <div className="flex items-center gap-2 bg-gray-50 rounded-xl border border-border px-4 py-3">
                  <span className="text-xs text-muted flex-1">Ask about your research...</span>
                  <div className="w-7 h-7 bg-foreground rounded-lg flex items-center justify-center">
                    <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="3" strokeLinecap="round"><path d="M22 2L11 13M22 2l-7 20-4-9-9-4 20-7z" /></svg>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Right: Copy */}
          <div className="order-1 md:order-2">
            <p className="text-sm font-medium text-muted mb-3 tracking-wide uppercase">Pinda AI</p>
            <h2 className="font-serif text-3xl md:text-5xl font-bold tracking-tight leading-tight mb-6">
              Your research, <br />
              <span className="italic text-muted/60">answering back.</span>
            </h2>
            <p className="text-muted leading-relaxed mb-8 max-w-md">
              Pinda reads your saved papers, notes and highlights, then answers questions
              with citations pointing back to your own materials. Not a generic chatbot —
              an assistant that knows what you&apos;ve read.
            </p>
            <div className="space-y-4">
              {[
                "Grounded in your library, not the entire internet",
                "Scope to a category, topic, or single paper",
                "Conversational — refine your question naturally",
                "Powered by Claude for nuanced understanding",
              ].map((line, i) => (
                <div key={i} className="flex items-start gap-3">
                  <div className="mt-0.5 w-5 h-5 rounded-full bg-foreground flex items-center justify-center shrink-0">
                    <svg width="10" height="10" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"><path d="M20 6L9 17l-5-5" /></svg>
                  </div>
                  <span className="text-sm">{line}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </section>
  );
}
