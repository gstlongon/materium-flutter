import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  String _selectedRole = 'comprador';
  final List<String> _roles = ['comprador', 'fornecedor'];

  void _register() async {
    final name = _nameController.text;
    final email = _emailController.text;
    final password = _passwordController.text;
    final role = _selectedRole;

    final success = await _authService.register(name, email, password, role);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cadastro realizado com sucesso!')));
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao cadastrar usuário')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.person_add, size: 64, color: Theme.of(context).primaryColor),
              SizedBox(height: 16),
              Text("Criar Conta", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              SizedBox(height: 32),
              _buildInputField(controller: _nameController, label: "Nome", icon: Icons.person),
              SizedBox(height: 16),
              _buildInputField(controller: _emailController, label: "Email", icon: Icons.email),
              SizedBox(height: 16),
              _buildInputField(controller: _passwordController, label: "Senha", icon: Icons.lock, obscure: true),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                items: _roles.map((role) => DropdownMenuItem(value: role, child: Text(role))).toList(),
                decoration: InputDecoration(
                  labelText: "Tipo de usuário",
                  prefixIcon: Icon(Icons.group),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value!;
                  });
                },
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: _register,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text("Registrar"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen()));
                },
                child: Text("Já tem uma conta? Entrar"),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
