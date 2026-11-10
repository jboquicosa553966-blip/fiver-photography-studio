# Supabase backend setup

1. Create a Supabase project.
2. Run migrations in \`supabase/migrations/\` in timestamp order.
3. Enable Email OTP/magic link authentication. Set Site URL and redirect allow-list to the deployed site.
4. Deploy functions using the Supabase CLI:
   \`\`\`sh
   supabase login
   supabase link --project-ref YOUR_PROJECT_REF
   supabase db push
   supabase functions deploy create-checkout --no-verify-jwt
   supabase functions deploy paymongo-webhook --no-verify-jwt
   supabase functions deploy my-bookings --no-verify-jwt
   \`\`\`
5. Configure secrets:
   \`\`\`sh
   supabase secrets set SITE_URL=https://jboquicosa553966-blip.github.io/fiver-photography-studio
   supabase secrets set SITE_ORIGIN=https://jboquicosa553966-blip.github.io
   supabase secrets set PAYMONGO_SECRET_KEY=sk_test_REPLACE_ME
   supabase secrets set PAYMONGO_WEBHOOK_SECRET=whsk_REPLACE_ME
   \`\`\`
   Supabase injects SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY. Never commit secret keys.
6. In PayMongo Dashboard > Developers > Webhooks, register the deployed paymongo-webhook function URL and subscribe to checkout_session.payment.paid. Store the endpoint signing secret in Supabase.
7. Copy js/supabase-config.example.js to js/supabase-config.js and fill in the Supabase project URL and anon key. These are public browser values; never use the service-role key.
8. Test with PayMongo test mode first. Enable only the payment methods active on the PayMongo account.

## Security and business rules
- Booking creation must call public.create_booking_hold() after customer authentication. A PostgreSQL exclusion constraint blocks overlapping sessions including the 15-minute turnover buffer.
- Unpaid holds are released after 15 minutes. Run select public.expire_unpaid_booking_holds() on a Supabase Cron schedule as well as insert-time cleanup.
- A payment becomes confirmed only after a valid, signed PayMongo webhook. The success redirect is not proof of payment.
- Cancellation requests are recorded for staff review; no automatic refund is issued. Staff should apply the studio's published 24-hour cancellation policy and refund decision manually.
- Refund automation, rescheduling, email/SMS dispatch, subscriptions, vouchers, and gallery email delivery need additional verified policy and provider credentials.
- This is not live until a Supabase project is linked, migrations and functions are deployed, and keys/webhooks are configured.
