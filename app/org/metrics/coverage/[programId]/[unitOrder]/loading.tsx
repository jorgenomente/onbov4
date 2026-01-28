export default function CoverageDetailLoading() {
  return (
    <main className="mx-auto flex min-h-screen w-full max-w-4xl flex-col gap-6 px-4 py-6">
      <div className="h-6 w-56 animate-pulse rounded bg-slate-200" />
      <div className="h-4 w-64 animate-pulse rounded bg-slate-200" />
      <div className="h-64 animate-pulse rounded-lg border border-slate-200 bg-white" />
      <div className="h-48 animate-pulse rounded-lg border border-slate-200 bg-white" />
    </main>
  );
}
