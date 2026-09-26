import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';

interface ProverbsState {
  proverbs: string[];
}

interface ProverbsSectionProps {
  state: ProverbsState;
  setState: (state: ProverbsState) => void;
}

export function ProverbsSection({ state, setState }: ProverbsSectionProps) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>AIが生成したことわざ</CardTitle>
        <CardDescription>
          右側のAIアシスタントに話しかけて新しいことわざを追加できます
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-3">
        {state.proverbs?.map((proverb, index) => (
          <div 
            key={index} 
            className="group flex items-start gap-3 rounded-lg border bg-gray-50 p-4 transition-colors hover:bg-gray-100"
          >
            <span className="flex h-6 w-6 flex-shrink-0 items-center justify-center rounded-md bg-blue-100 text-sm font-semibold text-blue-600">
              {index + 1}
            </span>
            <p className="flex-1 text-sm text-gray-900">{proverb}</p>
            <Button
              variant="ghost"
              size="icon"
              className="h-6 w-6 opacity-0 transition-opacity group-hover:opacity-100"
              onClick={() => setState({ ...state, proverbs: state.proverbs.filter((_, i) => i !== index) })}
            >
              <svg className="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
              </svg>
            </Button>
          </div>
        ))}
        
        {state.proverbs?.length === 0 && (
          <div className="py-12 text-center text-sm text-muted-foreground">
            <p>まだことわざがありません</p>
            <p className="mt-1">AIアシスタントに話しかけてください</p>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
