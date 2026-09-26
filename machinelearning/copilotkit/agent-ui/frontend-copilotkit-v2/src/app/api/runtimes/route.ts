import { NextRequest, NextResponse } from 'next/server';
import { auth } from '@/auth';
import { getAllRuntimes, fetchAgentsFromRuntime } from '@/lib/runtime';

/**
 * GET /api/runtimes
 * 
 * Retrieve all available AgentCore Runtimes
 * Optionally include agent count for each runtime
 */
export async function GET(req: NextRequest) {
  try {
    // Check authentication
    const session = await auth();
    if (!session?.user?.sub) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      );
    }

    // Get query parameters
    const searchParams = req.nextUrl.searchParams;
    const includeAgentCount = searchParams.get('includeAgentCount') === 'true';

    // Fetch all runtimes from DynamoDB
    const runtimes = await getAllRuntimes();

    // If includeAgentCount is true, fetch agent count for each runtime
    if (includeAgentCount) {
      const runtimesWithAgentCount = await Promise.all(
        runtimes.map(async (runtime) => {
          try {
            const agents = await fetchAgentsFromRuntime(
              runtime,
              session.idToken
            );
            const agentCount = Object.keys(agents).length;
            
            return {
              ...runtime,
              agentCount,
            };
          } catch (error) {
            console.error(`Error fetching agents for ${runtime.runtimeId}:`, error);
            return {
              ...runtime,
              agentCount: 0,
            };
          }
        })
      );

      return NextResponse.json({
        runtimes: runtimesWithAgentCount,
        count: runtimesWithAgentCount.length,
      });
    }

    // Return runtimes without agent count
    return NextResponse.json({
      runtimes,
      count: runtimes.length,
    });
  } catch (error) {
    console.error('Error in GET /api/runtimes:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}
