import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'login_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const DashboardScreen({super.key, required this.user});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

enum OrdenarPor { nomeAsc, nomeDesc, precoAsc, precoDesc }

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> todosProdutos = [];
  List<dynamic> produtosFiltrados = [];
  bool carregando = true;
  int paginaAtual = 0;
  final int produtosPorPagina = 20;
  late SharedPreferences prefs;

  String termoBusca = '';
  OrdenarPor ordenacaoSelecionada = OrdenarPor.nomeAsc;

  @override
  void initState() {
    super.initState();
    inicializar();
  }

  Future<void> inicializar() async {
    prefs = await SharedPreferences.getInstance();
    await buscarProdutos();
  }

  Future<void> buscarProdutos() async {
    setState(() => carregando = true);

    final token = prefs.getString('token');
    if (token == null) {
      mostrarMensagem('Token não encontrado');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://materium-api.vercel.app/api/products'),
        headers: _headers(token),
      );

      if (response.statusCode == 200) {
        final produtosApi = json.decode(response.body);
        final produtosValidos =
            produtosApi.where((p) => p['price'] != null).toList();

        setState(() {
          todosProdutos = produtosValidos;
          aplicarFiltroEOrdenacao();
          carregando = false;
        });
      } else {
        mostrarMensagem('Erro ao carregar produtos (${response.statusCode})');
        setState(() => carregando = false);
      }
    } catch (e) {
      mostrarMensagem('Erro: $e');
      setState(() => carregando = false);
    }
  }

  void aplicarFiltroEOrdenacao() {
    // Filtra pelo termo de busca (nome)
    produtosFiltrados = todosProdutos.where((produto) {
      final nome = produto['name']?.toString().toLowerCase() ?? '';
      return nome.contains(termoBusca.toLowerCase());
    }).toList();

    // Ordena conforme selecionado
    produtosFiltrados.sort((a, b) {
      switch (ordenacaoSelecionada) {
        case OrdenarPor.nomeAsc:
          return (a['name'] ?? '').toString().compareTo((b['name'] ?? '').toString());
        case OrdenarPor.nomeDesc:
          return (b['name'] ?? '').toString().compareTo((a['name'] ?? '').toString());
        case OrdenarPor.precoAsc:
          return (a['price'] ?? 0).compareTo(b['price'] ?? 0);
        case OrdenarPor.precoDesc:
          return (b['price'] ?? 0).compareTo(a['price'] ?? 0);
      }
    });

    // Reset paginação para a primeira página após filtro/ordenação
    paginaAtual = 0;
  }

  List<dynamic> obterPagina(List<dynamic> lista) {
    final inicio = paginaAtual * produtosPorPagina;
    final fim = (inicio + produtosPorPagina).clamp(0, lista.length);
    return lista.sublist(inicio, fim);
  }

  Future<void> criarOuEditarProduto({
    String? id,
    required String nome,
    required String descricao,
    required double preco,
    String? imagemUrl,
  }) async {
    final token = prefs.getString('token');
    if (token == null) return;

    final url = Uri.parse(
        'https://materium-api.vercel.app/api/products${id != null ? '/$id' : ''}');
    final body = json.encode({
      'name': nome,
      'description': descricao,
      'price': preco,
      if (imagemUrl != null && imagemUrl.isNotEmpty) 'imageUrl': imagemUrl,
    });

    final response = await (id == null
        ? http.post(url, headers: _headers(token), body: body)
        : http.put(url, headers: _headers(token), body: body));

    final sucesso = (id == null && response.statusCode == 201) ||
        (id != null && response.statusCode == 200);

    mostrarMensagem(sucesso ? 'Produto salvo com sucesso!' : 'Erro ao salvar produto.');

    if (sucesso) await buscarProdutos();
  }

  Future<void> deletarProduto(String id) async {
    final token = prefs.getString('token');
    if (token == null) return;

    final response = await http.delete(
      Uri.parse('https://materium-api.vercel.app/api/products/$id'),
      headers: _headers(token),
    );

    final sucesso = response.statusCode == 200;
    mostrarMensagem(sucesso ? 'Produto deletado com sucesso!' : 'Erro ao deletar produto.');

    if (sucesso) await buscarProdutos();
  }

  Map<String, String> _headers(String? token) => {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };

  void mostrarMensagem(String mensagem) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensagem)));
    }
  }

  void abrirFormulario({Map<String, dynamic>? produto}) {
    final nome = TextEditingController(text: produto?['name']);
    final descricao = TextEditingController(text: produto?['description']);
    final preco = TextEditingController(
        text: produto?['price']?.toStringAsFixed(2) ?? '');
    final imagem = TextEditingController(text: produto?['imageUrl']);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(produto != null ? 'Editar Produto' : 'Novo Produto'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: nome, decoration: const InputDecoration(labelText: 'Nome')),
              TextField(controller: descricao, decoration: const InputDecoration(labelText: 'Descrição')),
              TextField(controller: preco, decoration: const InputDecoration(labelText: 'Preço'), keyboardType: TextInputType.number),
              TextField(controller: imagem, decoration: const InputDecoration(labelText: 'URL da Imagem')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final nomeVal = nome.text.trim();
              final descVal = descricao.text.trim();
              final precoVal = double.tryParse(preco.text) ?? -1;

              if (nomeVal.isEmpty || descVal.isEmpty || precoVal < 0) {
                mostrarMensagem('Preencha todos os campos corretamente.');
                return;
              }

              criarOuEditarProduto(
                id: produto?['_id'],
                nome: nomeVal,
                descricao: descVal,
                preco: precoVal,
                imagemUrl: imagem.text.trim(),
              );

              Navigator.pop(context);
            },
            child: Text(produto != null ? 'Salvar' : 'Criar'),
          ),
        ],
      ),
    );
  }

  void confirmarExclusao(String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: const Text('Deseja realmente excluir este produto?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              deletarProduto(id);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFornecedor = widget.user['role'] == 'fornecedor';
    final userId = widget.user['_id'] ?? widget.user['id'];

    final produtosVisiveis = isFornecedor
        ? produtosFiltrados.where((p) {
            final criadoPor = p['createdBy'];
            return (criadoPor is Map && criadoPor['_id'] == userId) ||
                (criadoPor is String && criadoPor == userId);
          }).toList()
        : produtosFiltrados;

    final produtosPaginados = obterPagina(produtosVisiveis);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF005BAA),
        title: TextField(
          decoration: const InputDecoration(
            hintText: 'Buscar por nome...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
            iconColor: Colors.white,
          ),
          style: const TextStyle(color: Colors.white),
          onChanged: (valor) {
            setState(() {
              termoBusca = valor;
              aplicarFiltroEOrdenacao();
            });
          },
        ),
        actions: [
          DropdownButton<OrdenarPor>(
            value: ordenacaoSelecionada,
            dropdownColor: Colors.blue,
            underline: const SizedBox.shrink(),
            icon: const Icon(Icons.sort, color: Colors.white),
            items: const [
              DropdownMenuItem(
                value: OrdenarPor.nomeAsc,
                child: Text('Nome ↑', style: TextStyle(color: Colors.white)),
              ),
              DropdownMenuItem(
                value: OrdenarPor.nomeDesc,
                child: Text('Nome ↓', style: TextStyle(color: Colors.white)),
              ),
              DropdownMenuItem(
                value: OrdenarPor.precoAsc,
                child: Text('Preço ↑', style: TextStyle(color: Colors.white)),
              ),
              DropdownMenuItem(
                value: OrdenarPor.precoDesc,
                child: Text('Preço ↓', style: TextStyle(color: Colors.white)),
              ),
            ],
            onChanged: (novoValor) {
              if (novoValor != null) {
                setState(() {
                  ordenacaoSelecionada = novoValor;
                  aplicarFiltroEOrdenacao();
                });
              }
            },
          ),
          IconButton(
            color: Colors.white,
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await prefs.clear();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: isFornecedor
          ? FloatingActionButton(
              onPressed: () => abrirFormulario(),
              child: const Icon(Icons.add),
            )
          : null,
      body: carregando
          ? const Center(child: CircularProgressIndicator())
          : produtosVisiveis.isEmpty
              ? const Center(child: Text('Nenhum produto encontrado'))
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: produtosPaginados.length,
                        itemBuilder: (context, index) {
                          final produto = produtosPaginados[index];

                          // Imagem com placeholder local
                          Widget imagemWidget;
                          if (produto['imageUrl'] != null && produto['imageUrl'].toString().isNotEmpty) {
                            imagemWidget = Image.network(
                              produto['imageUrl'],
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 180,
                                  color: Colors.grey[300],
                                  child: const Center(child: Icon(Icons.broken_image)),
                                );
                              },
                            );
                          } else {
                            imagemWidget = Container(
                              height: 180,
                              color: Colors.grey[300],
                              child: const Center(child: Icon(Icons.image)),
                            );
                          }

                          return Card(
                            margin: const EdgeInsets.all(10),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    produto['name'] ?? 'Sem nome',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                  ),
                                  const SizedBox(height: 5),
                                  imagemWidget,
                                  const SizedBox(height: 10),
                                  Text(produto['description'] ?? ''),
                                  const SizedBox(height: 10),
                                  Text('R\$ ${produto['price']?.toStringAsFixed(2) ?? '0.00'}'),
                                  const SizedBox(height: 10),
                                  if (isFornecedor)
                                    Row(
                                      children: [
                                        ElevatedButton(
                                          onPressed: () => abrirFormulario(produto: produto),
                                          child: const Text('Editar'),
                                        ),
                                        const SizedBox(width: 10),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white
                                            ),
                                          onPressed: () => confirmarExclusao(produto['_id']),
                                          child: const Text('Excluir'),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if ((paginaAtual + 1) * produtosPorPagina < produtosVisiveis.length)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              paginaAtual++;
                            });
                          },
                          child: const Text('Carregar Mais'),
                        ),
                      ),
                  ],
                ),
    );
  }
}
