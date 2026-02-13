import { Card, CardContent } from '@/components/ui/card';
import { WeatherToolResult } from '@/mastra/tools';

interface WeatherCardProps {
  location?: string;
  result: WeatherToolResult;
  status: string;
}

export function WeatherCard({ location, result, status }: WeatherCardProps) {
  if (status !== "complete") {
    return (
      <Card className="mt-4">
        <CardContent className="pt-6">
          <p className="animate-pulse text-sm text-muted-foreground">天気情報を取得中...</p>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className="mt-4 border-none bg-gradient-to-br from-blue-500 to-indigo-600 text-white">
      <CardContent className="pt-6">
        <div className="flex items-start justify-between">
          <div>
            <h3 className="text-xl font-semibold capitalize">{location}</h3>
            <p className="text-sm text-blue-100">現在の天気</p>
          </div>
          <span className="text-4xl">{getWeatherEmoji(result.conditions)}</span>
        </div>
        
        <div className="mt-4 flex items-end justify-between">
          <div className="text-3xl font-bold">{result.temperature}°C</div>
          <p className="text-sm text-blue-100">{result.conditions}</p>
        </div>
        
        <div className="mt-4 grid grid-cols-3 gap-4 border-t border-white/20 pt-4 text-sm">
          <div>
            <p className="text-xs text-blue-100">湿度</p>
            <p className="font-semibold">{result.humidity}%</p>
          </div>
          <div>
            <p className="text-xs text-blue-100">風速</p>
            <p className="font-semibold">{result.windSpeed} mph</p>
          </div>
          <div>
            <p className="text-xs text-blue-100">体感</p>
            <p className="font-semibold">{result.feelsLike}°</p>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}

function getWeatherEmoji(conditions: string): string {
  const c = conditions?.toLowerCase() || '';
  if (c.includes('clear') || c.includes('sunny')) return '☀️';
  if (c.includes('rain')) return '🌧️';
  if (c.includes('cloud')) return '☁️';
  if (c.includes('snow')) return '❄️';
  return '🌤️';
}
