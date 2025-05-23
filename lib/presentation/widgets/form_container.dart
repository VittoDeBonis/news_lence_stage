import 'package:flutter/material.dart';

class FormContainer extends StatefulWidget {
  final TextEditingController? controller;
  final Key? fieldKey;
  final bool? isPasswordField;
  final String? hintText;
  final String? labelText;
  final String? helperText;
  final FormFieldSetter<String>? onSaved;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputType inputType;

  const FormContainer({
    super.key,
    this.controller,
    this.fieldKey, 
    this.isPasswordField, 
    this.hintText, 
    this.labelText, 
    this.helperText, 
    this.onSaved, 
    this.validator, 
    this.onFieldSubmitted, 
      required this.inputType, required Icon prefixIcon
  });

  @override
  State<FormContainer> createState() =>  _FormContainerState();
}

class _FormContainerState extends State<FormContainer> {
bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child:  TextFormField(
        style: const TextStyle(color: Colors.blue),
        controller: widget.controller,
        keyboardType: widget.inputType,
        key: widget.fieldKey,
        obscureText: widget.isPasswordField == true ? _obscureText : false,
        onSaved: widget.onSaved,
        validator: widget.validator,
        onFieldSubmitted: widget.onFieldSubmitted,
        decoration: InputDecoration(
          border: InputBorder.none,
          filled: true,
          hintText: widget.hintText,
          hintStyle: const TextStyle(color: Colors.black),
          suffixIcon: GestureDetector(
            onTap: () {
              setState(() {
                _obscureText = !_obscureText;
              });
            },
            child: widget.isPasswordField == true ? Icon(_obscureText ? Icons.visibility_off : Icons.visibility, color: _obscureText == false ? Colors.blue : Colors.grey) : null,
          )
        ),
      ),
    );
  }
}