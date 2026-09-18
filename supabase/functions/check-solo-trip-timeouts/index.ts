import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

serve(async (req) => {
  try {
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // 1. Find all active sessions where next_checkin_due_at has passed
    const { data: overdueSessions, error: sessionError } = await supabase
      .from('solo_trip_sessions')
      .select(`
        id, 
        user_id, 
        grace_period_minutes, 
        next_checkin_due_at, 
        alert_contact_ids,
        users ( email, name )
      `)
      .eq('status', 'active')
      .lte('next_checkin_due_at', new Date().toISOString());

    if (sessionError) throw sessionError;

    const escalatedCount = [];

    for (const session of overdueSessions ?? []) {
      // Calculate grace period
      const dueTime = new Date(session.next_checkin_due_at);
      const graceTime = new Date(dueTime.getTime() + session.grace_period_minutes * 60000);
      const now = new Date();

      if (now > graceTime) {
        // 2. Mark session escalated (we update the checkin_log normally, but here we just send the email)
        
        // 3. Fetch emergency contacts emails
        const { data: contacts } = await supabase
          .from('emergency_contacts')
          .select('email, name')
          .in('id', session.alert_contact_ids);

        const contactEmails = contacts?.map(c => c.email).filter(Boolean) ?? [];
        
        if (contactEmails.length > 0 && RESEND_API_KEY) {
          // Send Email via Resend
          const userName = session.users?.name ?? "A user";
          const res = await fetch("https://api.resend.com/emails", {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "Authorization": `Bearer ${RESEND_API_KEY}`
            },
            body: JSON.stringify({
              from: "Durga Alerts <alerts@resend.dev>",
              to: contactEmails,
              subject: `URGENT: ${userName} missed a safety check-in`,
              html: `<p><strong>${userName}</strong> missed their scheduled safety check-in on the Durga app and the grace period has expired.</p><p>Please contact them immediately.</p>`
            })
          });
          
          if (!res.ok) {
            console.error("Failed to send email", await res.text());
          } else {
             escalatedCount.push(session.id);
          }
        }
      }
    }

    return new Response(
      JSON.stringify({ message: "Check-in processing complete", escalated: escalatedCount.length }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (err) {
    return new Response(String(err?.message ?? err), { status: 500 });
  }
});
