from deoplete.base.source import Base
from deoplete.util import Candidates, Nvim, UserContext


class Source(Base):
    def __init__(self, vim: Nvim) -> None:
        super().__init__(vim)
        self.name = "pug"
        self.mark = "[pug]"
        self.min_pattern_length = 1
        self.rank = 100
        self.filetypes = ["pug"]

    def get_complete_position(self, context: UserContext) -> int:
        try:
            return self.vim.call("pugcomplete#CompletePug", 1, "")
        except:
            return -1

    def gather_candidates(self, context) -> Candidates:
        return self.vim.call("pugcomplete#CompletePug", 0, context["complete_str"])
