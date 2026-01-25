export default function Loading() {
  return (
    <main className="mx-auto flex min-h-screen w-full max-w-xl flex-col gap-4 px-4 py-6">
      <div className="h-6 w-32 animate-pulse rounded bg-slate-200" />
      <div className="h-24 w-full animate-pulse rounded bg-slate-100" />
      <div className="h-24 w-full animate-pulse rounded bg-slate-100" />
    </main>
  );
}
