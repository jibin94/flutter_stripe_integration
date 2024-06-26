import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_stripe_integration/future_card_pay/response_card.dart';
import 'package:flutter_stripe_integration/util/app_constants.dart';
import 'package:flutter_stripe_integration/util/utils.dart';
import 'package:http/http.dart' as http;
import 'loading_button.dart';

class SetupFuturePaymentScreen extends StatefulWidget {
  const SetupFuturePaymentScreen({super.key});

  @override
  SetupFuturePaymentScreenState createState() =>
      SetupFuturePaymentScreenState();
}

class SetupFuturePaymentScreenState extends State<SetupFuturePaymentScreen> {
  PaymentIntent? _retrievedPaymentIntent;
  CardFieldInputDetails? _card;
  SetupIntent? _setupIntentResult;
  String _email = 'email@stripe.com';

  int step = 0;
  final ControlsWidgetBuilder emptyControlBuilder = (_, __) => Container();


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(
          color: Colors.white
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text(
          "Save Card",
          style: TextStyle(fontSize: 18,color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextFormField(
                initialValue: _email,
                decoration:
                    const InputDecoration(hintText: 'Email', labelText: 'Email'),
                onChanged: (value) {
                  setState(() {
                    _email = value;
                  });
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: CardField(
                onCardChanged: (card) {
                  setState(() {
                    _card = card;
                  });
                },
              ),
            ),
            Stepper(
              controlsBuilder: emptyControlBuilder,
              currentStep: step,
              steps: [
                Step(
                  title: const Text('Save card'),
                  content: LoadingButton(
                    onPressed: _card?.complete == true ? _handleSavePress : null,
                    text: 'Save',
                  ),
                ),
                Step(
                  title: const Text('Pay with saved card'),
                  content: LoadingButton(
                    onPressed: _setupIntentResult != null
                        ? _handleOffSessionPayment
                        : null,
                    text: 'Pay with saved card off-session',
                  ),
                ),
                Step(
                  title: const Text('[Extra] Recovery Flow - Authenticate payment'),
                  content: Column(
                    children: [
                      const Text(
                          'If the payment did not succeed. Notify your customer to return to your application to complete the payment. We recommend creating a recovery flow in your app that shows why the payment failed initially and lets your customer retry.'),
                      const SizedBox(height: 8),
                      LoadingButton(
                        onPressed: _retrievedPaymentIntent != null
                            ? _handleRecoveryFlow
                            : null,
                        text: 'Authenticate payment (recovery flow)',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_setupIntentResult != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: ResponseCard(
                  response: _setupIntentResult!.toJson().toPrettyString(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSavePress() async {
    if (_card == null) {
      return;
    }
    try {
      // 1. Create setup intent on backend
      final clientSecret = await _createSetupIntentOnBackend(_email);

      // 2. Gather customer billing information (ex. email)
      const billingDetails = BillingDetails(
        name: "Test User",
        email: 'email@stripe.com',
        phone: '+48888000888',
        address: Address(
          city: 'Houston',
          country: 'US',
          line1: '1459  Circle Drive',
          line2: '',
          state: 'Texas',
          postalCode: '77063',
        ),
      ); // mocked data for tests

      // 3. Confirm setup intent

      final setupIntentResult = await Stripe.instance.confirmSetupIntent(
        paymentIntentClientSecret: clientSecret,
        params: const PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(
            billingDetails: billingDetails,
          ),
        ),
      );
      log('Setup Intent created $setupIntentResult');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Success: Setup intent created.',
          ),
        ),
      );
      setState(() {
        step = 1;
        _setupIntentResult = setupIntentResult;
      });
    } catch (error) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error code: $error')));
      rethrow;
    }
  }

  Future<void> _handleOffSessionPayment() async {
    final res = await _chargeCardOffSession();
    if (res['error'] != null) {
      // If the PaymentIntent has any other status, the payment did not succeed and the request fails.
      // Notify your customer e.g., by email, text, push notification) to complete the payment.
      // We recommend creating a recovery flow in your app that shows why the payment failed initially and lets your customer retry.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Error!: The payment could not be completed! ${res['error']}')));
      await _handleRetrievePaymentIntent(res['clientSecret']);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Success!: The payment was confirmed successfully!')));
      setState(() {
        step = 2;
      });
    }

    log('charge off session result: $res');
  }

  // When customer back to the App to complete the payment, retrieve the PaymentIntent via clientSecret.
  // Check the PaymentIntent’s lastPaymentError to inspect why the payment attempt failed.
  // For card errors, you can show the user the last payment error’s message. Otherwise, you can show a generic failure message.
  Future<void> _handleRetrievePaymentIntent(String clientSecret) async {
    final paymentIntent =
        await Stripe.instance.retrievePaymentIntent(clientSecret);

    final paymentMethodId = paymentIntent.paymentMethodId ?? _setupIntentResult?.paymentMethodId;

    setState(() {
      _retrievedPaymentIntent =
          paymentIntent.copyWith(paymentMethodId: paymentMethodId);
    });
  }

  //  https://stripe.com/docs/payments/save-and-reuse?platform=ios#start-a-recovery-flow
  Future<void> _handleRecoveryFlow() async {
    // TODO lastPaymentError
    if (_retrievedPaymentIntent?.paymentMethodId != null && _card != null) {
      await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: _retrievedPaymentIntent!.clientSecret,
        data: PaymentMethodParams.cardFromMethodId(
          paymentMethodData: PaymentMethodDataCardFromMethod(
              paymentMethodId: _retrievedPaymentIntent!.paymentMethodId!),
        ),
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Success!: The payment was confirmed successfully!')));
  }

  Future<String> _createSetupIntentOnBackend(String email) async {
    final url = Uri.parse('${AppConstants().kApiUrl}/create-setup-intent');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'email': email,
      }),
    );
    final Map<String, dynamic> bodyResponse = json.decode(response.body);
    final clientSecret = bodyResponse['clientSecret'] as String;
    log('Client token  $clientSecret');

    return clientSecret;
  }

  Future<Map<String, dynamic>> _chargeCardOffSession() async {
    final url = Uri.parse('${AppConstants().kApiUrl}/charge-card-off-session');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: json.encode({'email': _email}),
    );
    return json.decode(response.body);
  }
}
