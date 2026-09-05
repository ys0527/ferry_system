import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'constants.dart';
import 'models/qr_ticket_data.dart';
import 'qr_ticket.dart';
import 'services/payment_service.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({
    required this.bookingId,
    required this.route,
    required this.date,
    required this.time,
    required this.ticketSummary,
    required this.fare,
    super.key,
  });

  final String bookingId;
  final String route;
  final String date;
  final String time;
  final String ticketSummary;
  final double fare;

  @override
  State<PaymentPage> createState() => _PaymentState();
}

class _PaymentState extends State<PaymentPage> {
  static const navy = Color(0xFF3472CA);
  static const teal = Color(0xFF1E93B8);
  static const ice = Color(0xFFEAF4F8);

  final _paymentService = PaymentService();

  bool _isPaying = false;

  bool _sheetOpen = false;

  Future<void> _payWithPaymentSheet() async {
    setState(() => _isPaying = true);

    try {
      final intent = await _paymentService.createPaymentIntent(
        bookingId: widget.bookingId,
      );

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: intent.clientSecret,
          merchantDisplayName: 'FerryLink Penang',
        ),
      );

      if (mounted) {
        setState(() {
          _isPaying = false;
          _sheetOpen = true;
        });
      }

      await Stripe.instance.presentPaymentSheet();

      if (mounted) {
        setState(() {
          _sheetOpen = false;
          _isPaying = true;
        });
      }

      final reference = await _paymentService.confirmBookingPaid(
        bookingId: widget.bookingId,
        paymentIntentId: intent.paymentIntentId,
        customerId: intent.customerId,
        amount: intent.amount,
      );

      if (!mounted) return;
      setState(() => _isPaying = false);
      await _showPointsEarnedDialog();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => QrTicketPage(
            initialData: QrTicketData(
              reference: reference,
              route: widget.route,
              date: widget.date,
              time: widget.time,
              ticketSummary: widget.ticketSummary,
              fare: widget.fare,
            ),
          ),
        ),
            (route) => route.isFirst,
      );
    } on StripeException catch (e) {
      if (!mounted) return;
      setState(() {
        _isPaying = false;
        _sheetOpen = false;
      });
      if (e.error.code != FailureCode.Canceled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: ${e.error.localizedMessage ?? e.error.code}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPaying = false;
        _sheetOpen = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  Future<void> _showPointsEarnedDialog() async {
    final points = rewardPointsFor(widget.fare);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Payment Successful'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your ticket has been generated.'),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.card_giftcard, color: teal, size: 18),
                const SizedBox(width: 8),
                Text('+$points Reward Points earned',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: navy)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: navy,
        title: const Text('Payment'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: ice, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Order Summary',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: navy)),
                const SizedBox(height: 10),
                _summaryRow('Route', widget.route),
                _summaryRow('Date', widget.date),
                _summaryRow('Time', widget.time),
                _summaryRow('Tickets', widget.ticketSummary),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: ice, borderRadius: BorderRadius.circular(12)),
            child: const Row(
              children: [
                Icon(Icons.lock, size: 16, color: navy),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "You'll be taken to Stripe's secure checkout to enter your card details.",
                    style: TextStyle(fontSize: 12, color: navy),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(14)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total to Pay', style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text('RM ${widget.fare.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: (_isPaying || _sheetOpen) ? null : _payWithPaymentSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: teal,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              child: _isPaying
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
                  : const Text('Pay Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: navy),
            ),
          ),
        ],
      ),
    );
  }
}