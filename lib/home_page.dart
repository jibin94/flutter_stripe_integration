import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_stripe_integration/future_card_pay/setup_future_payment_screen.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Map<String, dynamic>? paymentIntent;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text(
          "Flutter Stripe",
          style: TextStyle(fontSize: 18, color: Colors.white),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.green, // Foreground
                  ),
                  onPressed: () {
                    makePayment();
                  },
                  child: const Text(
                    "Pay Rs 10",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(
                height: 20,
              ),
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.green, // Foreground
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SetupFuturePaymentScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    "Save Card",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> makePayment() async {
    try {
      // Create payment intent data
      paymentIntent = await createPaymentIntent('10', 'INR');
      // initialise the payment sheet setup
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          // Client secret key from payment data
          paymentIntentClientSecret: paymentIntent!['client_secret'],
          googlePay: const PaymentSheetGooglePay(
              // Currency and country code
              // is according to India
              testEnv: true,
              currencyCode: "INR",
              merchantCountryCode: "IN"),
          // Merchant Name
          merchantDisplayName: 'Flutter Dev',
          // return URl if you want to add
          // returnURL: 'flutterstripe://redirect',
        ),
      );
      //Display payment sheet
      displayPaymentSheet();
    } catch (e) {
      debugPrint("exception $e");

      if (e is StripeConfigException) {
        debugPrint("Stripe exception ${e.message}");
      } else {
        debugPrint("exception $e");
      }
    }
  }

  createPaymentIntent(String amount, String currency) async {
    try {
      Map<String, dynamic> body = {
        // Amount must be in smaller unit of currency
        // so we have multiply it by 100
        'amount': ((int.parse(amount)) * 100).toString(),
        'currency': currency,
        'payment_method_types[]': 'card',
      };
      var response = await http.post(
        Uri.parse('https://api.stripe.com/v1/payment_intents'),
        headers: {
          'Authorization': 'Bearer ${dotenv.env['STRIPE_SECRET']}',
          'Content-Type': 'application/x-www-form-urlencoded'
        },
        body: body,
      );
      debugPrint('Payment Intent Body: ${response.body.toString()}');
      return jsonDecode(response.body.toString());
    } catch (err) {
      debugPrint('Error charging user: ${err.toString()}');
    }
  }

  displayPaymentSheet() async {
    try {
      // "Display payment sheet";
      await Stripe.instance.presentPaymentSheet();
      // Show when payment is done
      // Displaying snack bar for it
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Paid successfully")),
      );
      paymentIntent = null;
    } on StripeException catch (e) {
      // If any error comes during payment
      // so payment will be cancelled
      debugPrint('Error: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(" Payment Cancelled")),
      );
    } catch (e) {
      debugPrint("Error in displaying sheet: $e");
    }
  }
}
