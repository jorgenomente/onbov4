export default function FinalEvaluationLoading() {
  return (
    <main className="mx-auto flex min-h-screen w-full max-w-xl flex-col gap-4 px-4 py-6">
      <div className="h-6 w-40 animate-pulse rounded bg-slate-200" />
      <div className="h-4 w-64 animate-pulse rounded bg-slate-200" />
      <div className="h-32 w-full animate-pulse rounded border border-slate-200 bg-slate-50" />
      <div className="h-24 w-full animate-pulse rounded border border-slate-200 bg-slate-50" />
      <div className="h-10 w-full animate-pulse rounded bg-slate-200" />
    </main>
  );
}
