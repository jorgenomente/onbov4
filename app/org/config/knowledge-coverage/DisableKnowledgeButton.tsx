'use client';

import { useRef } from 'react';

type DisableKnowledgeButtonProps = {
  knowledgeId: string;
  programId: string;
  action: (formData: FormData) => void;
};

export function DisableKnowledgeButton({
  knowledgeId,
  programId,
  action,
}: DisableKnowledgeButtonProps) {
  const formRef = useRef<HTMLFormElement>(null);
  const reasonRef = useRef<HTMLInputElement>(null);

  const handleClick = () => {
    const confirmDisable = window.confirm(
      'Desactivar no borra. El item deja de usarse para el bot desde ahora. ¿Continuar?',
    );
    if (!confirmDisable) return;
    const reason = window.prompt('Motivo (opcional)', '') ?? '';
    if (reasonRef.current) {
      reasonRef.current.value = reason;
    }
    formRef.current?.requestSubmit();
  };

  return (
    <form ref={formRef} action={action} className="mt-2">
      <input type="hidden" name="knowledge_id" value={knowledgeId} />
      <input type="hidden" name="program_id" value={programId} />
      <input ref={reasonRef} type="hidden" name="reason" />
      <button
        type="button"
        onClick={handleClick}
        className="rounded-md border border-amber-200 px-2 py-1 text-[11px] font-semibold text-amber-700"
      >
        Desactivar
      </button>
    </form>
  );
}
