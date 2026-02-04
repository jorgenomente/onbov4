type ModeIndicatorProps = {
  mode: 'Aprender' | 'Practicar';
};

export default function ModeIndicator({ mode }: ModeIndicatorProps) {
  return (
    <div className="inline-flex items-center gap-2 rounded-full border border-slate-200 bg-white px-3 py-1 text-[11px] font-semibold text-slate-500">
      <span>Fase</span>
      <span
        className={`rounded-full px-2 py-0.5 ${
          mode === 'Aprender'
            ? 'bg-emerald-50 text-emerald-700'
            : 'bg-blue-50 text-blue-700'
        }`}
      >
        {mode}
      </span>
    </div>
  );
}
