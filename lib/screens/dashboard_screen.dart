import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  DashboardScreen({required this.user});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> todosProdutos = [];
  bool carregando = true;
  int paginaAtual = 0;
  final int produtosPorPagina = 20;

  @override
  void initState() {
    super.initState();
    buscarProdutos();
  }

  Future<void> buscarProdutos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) throw Exception("Token não encontrado");

      final url = Uri.parse('https://materium-api.vercel.app/api/products');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> produtosApi = json.decode(response.body);
        final produtosFiltrados = produtosApi
            .where((produto) => produto['price'] != null)
            .toList();

        setState(() {
          todosProdutos = produtosFiltrados;
          carregando = false;
        });
      } else {
        throw Exception("Erro ao carregar produtos: ${response.statusCode}");
      }
    } catch (e) {
      print("Erro: $e");
      setState(() {
        carregando = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao carregar produtos')));
    }
  }

  Future<void> criarProduto(
    String nome,
    String descricao,
    double preco,
    String? imagemUrl,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final url = Uri.parse('https://materium-api.vercel.app/api/products');

    final body = {
      "name": nome,
      "description": descricao,
      "price": preco,
      if (imagemUrl != null && imagemUrl.isNotEmpty) "imageUrl": imagemUrl,
    };

    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(body),
    );

    if (response.statusCode == 201) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Produto criado com sucesso!')));
      Future.delayed(Duration(milliseconds: 300), () {
        buscarProdutos(); // Atualiza a lista após fechar o diálogo
      });
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao criar produto.')));
    }
  }

  void abrirFormularioCriacao() {
    final _nomeController = TextEditingController();
    final _descController = TextEditingController();
    final _precoController = TextEditingController();
    final _imagemController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Novo Produto'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _nomeController,
                decoration: InputDecoration(labelText: 'Nome'),
              ),
              TextField(
                controller: _descController,
                decoration: InputDecoration(labelText: 'Descrição'),
              ),
              TextField(
                controller: _precoController,
                decoration: InputDecoration(labelText: 'Preço'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _imagemController,
                decoration: InputDecoration(labelText: 'URL da Imagem'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final nome = _nomeController.text;
              final desc = _descController.text;
              final preco = double.tryParse(_precoController.text) ?? 0;
              final imagem = _imagemController.text;
              criarProduto(nome, desc, preco, imagem);
              Navigator.pop(context);
            },
            child: Text('Criar'),
          ),
        ],
      ),
    );
  }

  List<dynamic> obterProdutosDaPagina(List<dynamic> lista) {
    int inicio = paginaAtual * produtosPorPagina;
    int fim = inicio + produtosPorPagina;
    return lista.sublist(inicio, fim > lista.length ? lista.length : fim);
  }

  @override
  Widget build(BuildContext context) {
    final isFornecedor = widget.user['role'] == 'fornecedor';

    final userId = widget.user['_id'] ?? widget.user['id'];
    final produtosExibidos = isFornecedor
        ? todosProdutos.where((p) {
            final createdBy = p['createdBy'];
            if (createdBy is Map && createdBy.containsKey('_id')) {
              return createdBy['_id'] == userId;
            }
            if (createdBy is String) {
              return createdBy == userId;
            }
            return false;
          }).toList()
        : todosProdutos;

    return Scaffold(
      appBar: AppBar(
        title: Text("Dashboard"),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            tooltip: 'Sair',
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: carregando
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Bem-vindo, ${widget.user['name']}! ",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: produtosExibidos.isEmpty
                      ? Center(child: Text("Nenhum produto encontrado"))
                      : ListView.builder(
                          itemCount: obterProdutosDaPagina(
                            produtosExibidos,
                          ).length,
                          itemBuilder: (context, index) {
                            final produto = obterProdutosDaPagina(
                              produtosExibidos,
                            )[index];
                            return Card(
                              margin: EdgeInsets.all(10),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    produto['imageUrl'] != null
                                        ? Image.network(
                                            produto['imageUrl'],
                                            height: 180,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            height: 180,
                                            color: Colors.grey[300],
                                            child: Center(
                                              child: Icon(Icons.image),
                                            ),
                                          ),
                                    SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          produto['name'] ?? 'Sem nome',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (!isFornecedor)
                                          IconButton(
                                            icon: Icon(Icons.add),
                                            onPressed: () {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Adicionado: ${produto['name']}',
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      produto['description'] ?? 'Sem descrição',
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Preço: R\$ ${(produto['price'] ?? 0).toStringAsFixed(2)}',
                                    ),
                                    Text(
                                      'Fornecedor: ${produto['createdBy']?['name'] ?? "Desconhecido"}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (produtosExibidos.length > produtosPorPagina)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                          onPressed: paginaAtual > 0
                              ? () {
                                  setState(() {
                                    paginaAtual--;
                                  });
                                }
                              : null,
                          child: Text('Anterior'),
                        ),
                        Text(
                          'Página ${paginaAtual + 1} de ${((produtosExibidos.length - 1) / produtosPorPagina + 1).floor()}',
                        ),
                        ElevatedButton(
                          onPressed:
                              (paginaAtual + 1) * produtosPorPagina <
                                  produtosExibidos.length
                              ? () {
                                  setState(() {
                                    paginaAtual++;
                                  });
                                }
                              : null,
                          child: Text('Próxima'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
      floatingActionButton: isFornecedor
          ? FloatingActionButton(
              onPressed: abrirFormularioCriacao,
              child: Icon(Icons.add),
              tooltip: 'Criar Produto',
            )
          : null,
    );
  }
}
