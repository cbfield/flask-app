import os

modules = [
    f[:-3] for f in os.listdir(os.path.dirname(os.path.abspath(__file__)))
    if f.endswith('.py') and f != '__init__.py'
]

blueprints = []
for module in modules:
    mod = __import__(name=f'{__name__}.{module}', fromlist=['views'])
    blueprints.append(mod.views)
