import Stripe from 'npm:stripe@17';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') ?? '', {
  apiVersion: '2024-06-20',
});

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

/// Looks the app user up server-side rather than trusting the client, so a
/// caller cannot bill someone else's Stripe Customer.
async function fetchAppUser(userId: string): Promise<{ email: string; name: string }> {
  const url = Deno.env.get('SUPABASE_URL');
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const response = await fetch(
    `${url}/rest/v1/users?user_id=eq.${encodeURIComponent(userId)}&select=email,name`,
    { headers: { apikey: key ?? '', Authorization: `Bearer ${key}` } },
  );
  if (!response.ok) {
    throw new Error(`Could not read user ${userId}: ${response.status}`);
  }
  const rows = await response.json();
  if (!Array.isArray(rows) || rows.length === 0) {
    throw new Error(`Unknown user ${userId}`);
  }
  return rows[0];
}

async function fetchPayableBooking(
  bookingId: string,
  userId: string,
): Promise<{ amountInSen: number }> {
  const url = Deno.env.get('SUPABASE_URL');
  const key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const response = await fetch(
    `${url}/rest/v1/booking?booking_id=eq.${encodeURIComponent(bookingId)}&select=total,status,user_id`,
    { headers: { apikey: key ?? '', Authorization: `Bearer ${key}` } },
  );
  if (!response.ok) {
    throw new Error(`Could not read booking ${bookingId}: ${response.status}`);
  }
  const rows = await response.json();
  if (!Array.isArray(rows) || rows.length === 0) {
    throw new Error(`Unknown booking ${bookingId}`);
  }

  const booking = rows[0];
  if (booking.user_id !== userId) {
    throw new Error(`Booking ${bookingId} does not belong to ${userId}`);
  }
  if (booking.status !== 'Pending') {
    throw new Error(`Booking ${bookingId} is already ${booking.status}`);
  }

  const total = Number(booking.total);
  if (!Number.isFinite(total) || total <= 0) {
    throw new Error(`Booking ${bookingId} has an unusable total`);
  }
  return { amountInSen: Math.round(total * 100) };
}


async function findOrCreateCustomer(email: string, name: string): Promise<string> {
  const existing = await stripe.customers.list({ email, limit: 1 });
  if (existing.data.length > 0) {
    return existing.data[0].id;
  }
  const created = await stripe.customers.create({ email, name });
  return created.id;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { booking_id, user_id } = await req.json();

    if (typeof booking_id !== 'string' || typeof user_id !== 'string') {
      return new Response(
        JSON.stringify({
          error: 'booking_id (string) and user_id (string) are required',
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const { amountInSen } = await fetchPayableBooking(booking_id, user_id);
    const user = await fetchAppUser(user_id);
    const customerId = await findOrCreateCustomer(user.email, user.name);

    const paymentIntent = await stripe.paymentIntents.create({
      amount: amountInSen,
      currency: 'myr',
      customer: customerId,
      automatic_payment_methods: { enabled: true },
      metadata: { booking_id, user_id },
    });

    return new Response(
      JSON.stringify({
        clientSecret: paymentIntent.client_secret,
        paymentIntentId: paymentIntent.id,
        customerId,
        amount: amountInSen,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : String(error) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
